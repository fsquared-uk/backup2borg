# backup2borg.sh

A configurable script to allow automated backups to be sent to (multiple) borg
destinations.

This has been designed to fit in with the way I manage my backups, but hopefully
is configurable enough that it should work for others too.

The script reads a provided YAML configuration file, allowing the setting of:

* a list of backup source directories, each of which will go to it's own
  borg repo (named `directory.repo`)

* a list of borg end points (user, host, port) and options (e.g. compression)

* a pruning schedule, optionally different for each end point

## usage

Simply run the script from `cron` or your favourite scheduler; archives are
datestamped, so if an archive for the current day already exists on an endpoint
it will not be recreated.

The configuration file *must* be provided; optionally the `-l <level>` option
may be provided to enable more verbose working.

## requirements

An environment which has (a) bash, (b) ssh and (c) borg installed. I've only used
it in Linux environments; YMMV on other platforms (but issues and PRs are welcome).

## license

This script is released under GPLv3, rather than my normal MIT license; this is
primarily done because I include a GPLv3-licensed [YAML parser](https://github.com/mrbaseman/parse_yaml)
and frankly it's a lot less complicated to keep everything under the same
license.