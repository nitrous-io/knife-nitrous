# Nitrous.IO plugin for knife

This Knife plugin will let us create (using the EC2 API) and configure servers (using Chef-Solo) within
Nitrous.IO.

## Installation

Clone the repository:

    `$ git clone git@github.com:action-io/knife-nitrous.git`

Build and install the gem:

    `$ bundle exec rake build`
    `$ gem install pkg/knife-nitrous-x.y.z.gem`

Replace with whatever is the version specified in
`knife-nitrous/version.rb`

## Usage

knife nitrous create options

knife nitrous provision options

