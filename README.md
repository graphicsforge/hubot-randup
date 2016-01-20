hubot-randup
===================

Use a Slack Hubot to run randups.

## What is a randup?

Randups are random standups: an opportunity to share what is being worked on and what blockers are being worked through, but for larger organizations where it's time-prohibitive for everyone to share every single time, a random team-member is selected each time. This is meant to be run in conjunction to people keeping up-to-date within each project team, but additionally gives an opportunity to share what people are doing with the entire organization.

## What does it do?

In a slack channel, you can ask Hubot to create a randup at a specific time. From then on, at that time every weekday, Hubot will randomly select a user in that slack channel to give an update.

## Usage

`hubot randup help` - See a help document explaining how to use.

`hubot create randup hh:mm` - Creates a randup at hh:mm (UTC) every weekday for this room

`hubot create randup hh:mm UTC+2` - As above, with a shift to account for UTC offset

`hubot list randups` - See all randups for this room

`hubot list randups in every room` - See all randups in every room

`hubot delete hh:mm randup` - If you have a randup at hh:mm, deletes it

`hubot delete all randups` - Deletes all randups for this room.

## Local Time

Currently, the time you specify must be the same timezone as the server Hubot resides on. You can check this with `hubot time`. However, you can specify a UTC offset to compensate for any differences between Hubot's time and your local time.

## Installation

To enable the script, add the hubot-randup entry to the external-scripts.json file (you may need to create this file).

```
[
  "hubot-randup"
]
```

