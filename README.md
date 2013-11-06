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

## Setup

1. Create a `~/.chef/aws.json` JSON file with contents:
```
{
  "access_key": "AWS access key ID",
  "secret_key": "AWS secret access key"
}
```
1. Create a `nitrous.json` file where you declare how you want your EC2
instances will look like. knife-nitrous will magically provision your instances
according to your `nitrous.json` file. Some examples:
  1. [Coach's nitrous.json](https://github.com/action-io/coach-cookbook/blob/master/nitrous.json)
  1. [Boxhost's nitrous.json](https://github.com/action-io/boxhost_cookbook/blob/master/nitrous.json)
  1. [Rainbow's nitrous.json](https://github.com/action-io/rainbow-cookbook/blob/master/nitrous.json)
