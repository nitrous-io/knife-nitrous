# Nitrous.IO plugin for knife

This Knife plugin will let us create (using the EC2 API) and configure servers
(using Chef-Solo) within Nitrous.IO.

## Installation

Clone the repository:

    $ git clone git@github.com:action-io/knife-nitrous.git

Build and install the gem:

    $ bundle exec rake build
    $ gem install pkg/knife-nitrous-x.y.z.gem

Replace `x.y.z` with whatever version is specified in
[lib/knife-nitrous/version.rb](lib/knife-nitrous/version.rb).

## Usage

    knife nitrous bootstrap (options)
    knife nitrous create
    knife nitrous provision (options)

## Authenticating with AWS

knife-nitrous requires AWS security credentials. Place them in a
`~/.chef/aws.json` JSON file with contents:

```
{
  "access_key": "AWS access key ID",
  "secret_key": "AWS secret access key"
}
```

## Configuring knife-nitrous

knife-nitrous will look for config files in the following locations, in
ascending order of precedence:

* `~/.chef/nitrous.yml`
* `./nitrous.yml` (i.e. same directory where you run `knife nitrous`)

For example, a local `nitrous.yml` will override any settings in the
`~/.chef/nitrous.yml` file.

## HipChat integration

Notifications can be sent to a HipChat room and can be configured via the
`nitrous.yml` file(s).

```
---
hipchat:
  enabled: true
  key: replace-me # API key. Get one from https://hipchat.com/account/api or ask your HipChat admin.
  room: 1234 # HipChat room ID.
```
