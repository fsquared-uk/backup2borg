#!/bin/bash
#
# backup2borg.sh
#
# A script for managing automated borg archive creation.
#
# Copyright (C) 2023 fsquared limited <support@fsquared.co.uk>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

# Embed the YAML parser we'll use to read the configuration file; it's embedded
# rather than kept separate simply so that you only have to deploy one script.
#
# source: https://github.com/mrbaseman/parse_yaml.git (also GPLv3)

function parse_yaml {
   local prefix=$2
   local separator=${3:-_}

   local indexfix
   # Detect awk flavor
   if awk --version 2>&1 | grep -q "GNU Awk" ; then
      # GNU Awk detected
      indexfix=-1
   elif awk -Wv 2>&1 | grep -q "mawk" ; then
      # mawk detected
      indexfix=0
   fi

   local s='[[:space:]]*' sm='[ \t]*' w='[a-zA-Z0-9_]*' fs=${fs:-$(echo @|tr @ '\034')} i=${i:-  }
   cat $1 | \
   awk -F$fs "{multi=0; 
       if(match(\$0,/$sm\|$sm$/)){multi=1; sub(/$sm\|$sm$/,\"\");}
       if(match(\$0,/$sm>$sm$/)){multi=2; sub(/$sm>$sm$/,\"\");}
       while(multi>0){
           str=\$0; gsub(/^$sm/,\"\", str);
           indent=index(\$0,str);
           indentstr=substr(\$0, 0, indent+$indexfix) \"$i\";
           obuf=\$0;
           getline;
           while(index(\$0,indentstr)){
               obuf=obuf substr(\$0, length(indentstr)+1);
               if (multi==1){obuf=obuf \"\\\\n\";}
               if (multi==2){
                   if(match(\$0,/^$sm$/))
                       obuf=obuf \"\\\\n\";
                       else obuf=obuf \" \";
               }
               getline;
           }
           sub(/$sm$/,\"\",obuf);
           print obuf;
           multi=0;
           if(match(\$0,/$sm\|$sm$/)){multi=1; sub(/$sm\|$sm$/,\"\");}
           if(match(\$0,/$sm>$sm$/)){multi=2; sub(/$sm>$sm$/,\"\");}
       }
   print}" | \
   sed  -e "s|^\($s\)?|\1-|" \
       -ne "s|^$s#.*||;s|$s#[^\"']*$||;s|^\([^\"'#]*\)#.*|\1|;t1;t;:1;s|^$s\$||;t2;p;:2;d" | \
   sed -ne "s|,$s\]$s\$|]|" \
        -e ":1;s|^\($s\)\($w\)$s:$s\(&$w\)\?$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1\2: \3[\4]\n\1$i- \5|;t1" \
        -e "s|^\($s\)\($w\)$s:$s\(&$w\)\?$s\[$s\(.*\)$s\]|\1\2: \3\n\1$i- \4|;" \
        -e ":2;s|^\($s\)-$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1- [\2]\n\1$i- \3|;t2" \
        -e "s|^\($s\)-$s\[$s\(.*\)$s\]|\1-\n\1$i- \2|;p" | \
   sed -ne "s|,$s}$s\$|}|" \
        -e ":1;s|^\($s\)-$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1- {\2}\n\1$i\3: \4|;t1" \
        -e "s|^\($s\)-$s{$s\(.*\)$s}|\1-\n\1$i\2|;" \
        -e ":2;s|^\($s\)\($w\)$s:$s\(&$w\)\?$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1\2: \3 {\4}\n\1$i\5: \6|;t2" \
        -e "s|^\($s\)\($w\)$s:$s\(&$w\)\?$s{$s\(.*\)$s}|\1\2: \3\n\1$i\4|;p" | \
   sed  -e "s|^\($s\)\($w\)$s:$s\(&$w\)\(.*\)|\1\2:\4\n\3|" \
        -e "s|^\($s\)-$s\(&$w\)\(.*\)|\1- \3\n\2|" | \
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\(---\)\($s\)||" \
        -e "s|^\($s\)\(\.\.\.\)\($s\)||" \
        -e "s|^\($s\)-$s[\"']\(.*\)[\"']$s\$|\1$fs$fs\2|p;t" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p;t" \
        -e "s|^\($s\)-$s\(.*\)$s\$|\1$fs$fs\2|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\?\(.*\)$s\$|\1$fs\2$fs\3|" \
        -e "s|^\($s\)[\"']\?\([^&][^$fs]\+\)[\"']$s\$|\1$fs$fs$fs\2|" \
        -e "s|^\($s\)[\"']\?\([^&][^$fs]\+\)$s\$|\1$fs$fs$fs\2|" \
        -e "s|$s\$||p" | \
   awk -F$fs "{
      gsub(/\t/,\"        \",\$1);
      if(NF>3){if(value!=\"\"){value = value \" \";}value = value  \$4;}
      else {
        if(match(\$1,/^&/)){anchor[substr(\$1,2)]=full_vn;getline};
        indent = length(\$1)/length(\"$i\");
        vname[indent] = \$2;
        value= \$3;
        for (i in vname) {if (i > indent) {delete vname[i]; idx[i]=0}}
        if(length(\$2)== 0){  vname[indent]= ++idx[indent] };
        vn=\"\"; for (i=0; i<indent; i++) { vn=(vn)(vname[i])(\"$separator\")}
        vn=\"$prefix\" vn;
        full_vn=vn vname[indent];
        if(vn==\"$prefix\")vn=\"$prefix$separator\";
        if(vn==\"_\")vn=\"__\";
      }
      assignment[full_vn]=value;
      if(!match(assignment[vn], full_vn))assignment[vn]=assignment[vn] \" \" full_vn;
      if(match(value,/^\*/)){
         ref=anchor[substr(value,2)];
         if(length(ref)==0){
           printf(\"%s=\\\"%s\\\"\n\", full_vn, value);
         } else {
           for(val in assignment){
              if((length(ref)>0)&&index(val, ref)==1){
                 tmpval=assignment[val];
                 sub(ref,full_vn,val);
                 if(match(val,\"$separator\$\")){
                    gsub(ref,full_vn,tmpval);
                 } else if (length(tmpval) > 0) {
                    printf(\"%s=\\\"%s\\\"\n\", val, tmpval);
                 }
                 assignment[val]=tmpval;
              }
           }
         }
      } else if (length(value) > 0) {
         printf(\"%s=\\\"%s\\\"\n\", full_vn, value);
      }
   }END{
      for(val in assignment){
         if(match(val,\"$separator\$\"))
            printf(\"%s=\\\"%s\\\"\n\", val, assignment[val]);
      }
   }"
}


####################################
## START OF backup2borg functions ##
####################################

function log
{
  local level=$1
  local message=$2

  # If the message is below our log level, don't write it
  if [ ${level} -gt ${LOG_LEVEL} ]
  then
    return
  fi

  # Check the log level
  if [ ! -z ${options_log_output} ]
  then
    # Ensure the directory exists
    mkdir -p `dirname ${options_log_output}`

    # And write the log to it
    echo -n "`date +'%Y-%m-%d %H:%M:%S'` " >> ${options_log_output}
    echo $message >> ${options_log_output}
  else
    # Just write to stdout
    echo -n "`date +'%Y-%m-%d %H:%M:%S'` "
    echo $message
  fi
}


###############################
## START OF backup2borg main ##
###############################


# Set up some basic defaults
LOG_LEVEL=2

# Process the command line
while getopts hvl: opt
do
  case $opt in
    v) echo "Backup2Borg.sh v0.1"
       exit 1;;
    l) ;;
    h | ? | *) 
      echo "usage: $0 [-hv] [-l <level>] config.yaml"
      exit 1;;
  esac
done
shift $(($OPTIND - 1))

# Check we have a configuration file, try to read it
if [ ! -f "$1" ]
then
  echo "Cannot read configuration file '$1'"
  exit 1
fi

# So, parse the configuration file, that should be in YAML format!
eval $(parse_yaml $1)

# Expand our list of source directories, so we know what repos we are working with
source_repos=()
for src in ${sources_directory_} 
do
  source_repos+=(`eval echo \\\$${src}`)
done

# Good; now, work through each repo one at a time, and process it through all
# defined targets
for repo in ${source_repos[@]}
do
  log 2 "Processing ${repo}"

  # Work through all targets
  for target in ${targets_}
  do
    # Derive the proper repo name for this target
    target_repo="`eval echo \\\$${target}_root`/`basename $repo`.repo"
    target_repo=`echo $target_repo|tr -s /`

    # Now, assemble the full borg repo designation
    if [ -z "`eval echo \\\$${target}_port`" ]
    then
      # No port defined; use the default
      borg_repo="`eval echo \\\$${target}_user`@`eval echo \\\$${target}_host`:${target_repo}"
    else
      # Include the port number
      borg_repo="ssh://`eval echo \\\$${target}_user`@`eval echo \\\$${target}_host`:`eval echo \\\$${target}_port`"

      # And if there is no leading slash, prefix the target
      case $target_repo in /*) ;; *)
        borg_repo="${borg_repo}/./"
      esac
      borg_repo="${borg_repo}${target_repo}"
    fi

    # Phew! Lastly, check to see if that repo exists, and if not create it
    export BORG_PASSPHRASE="`eval echo \\\$${target}_passphrase`"
    borg info ${borg_repo} > /dev/null 2>&1
    if [ $? -ne 0 ]
    then
      log 2 "${borg_repo} does not exist; creating"
      borg init --encryption repokey-blake2 ${borg_repo}
    fi

    # Great; now, check if the archive is already here; we only do daily backups
    borg info ${borg_repo}::daily-{now:%Y%m%d} > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
      # This means we've already run today
      log 2 "${borg_repo} already archived today - skipping"
    else
      # Good, this means it doesn't exist yet so we can make it
      borg create --compression lzma ${borg_repo}::daily-{now:%Y%m%d} ${repo}
    fi

    # All backed up; so now, run any pruning that's defined
    keep_daily="`eval echo \\\$${target}_keep_daily`"
    keep_weekly="`eval echo \\\$${target}_keep_weekly`"
    keep_monthly="`eval echo \\\$${target}_keep_monthly`"
    keep_yearly="`eval echo \\\$${target}_keep_yearly`"

    prune_args=""
    if [ ! -z "${keep_daily}" ]
    then
      prune_args="${prune_args} --keep-daily ${keep_daily}"
    fi
    if [ ! -z "${keep_weekly}" ]
    then
      prune_args="${prune_args} --keep-weekly ${keep_weekly}"
    fi
    if [ ! -z "${keep_monthly}" ]
    then
      prune_args="${prune_args} --keep-monthly ${keep_monthly}"
    fi
    if [ ! -z "${keep_yearly}" ]
    then
      prune_args="${prune_args} --keep-yearly ${keep_yearly}"
    fi

    # Only proceed with the pruning if we have *some* args
    if [ ! -z "${prune_args}" ]
    then
      borg prune ${prune_args} ${borg_repo}
    fi

  done

done


