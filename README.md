perl-lifx
=========

This is the start of a Perl bindings for the LIFX Bulbs.

it's early days but some basic functionality is available

### Note
The interface is **asynchronous**, this is due to the underlying protocol. I've chosen not to hide the asynchronous nature in the Perl bindings as hiding that sort of thing normally goes wrong ;-(

32bit system may not be able to do some tag operations as they use a 64bit mask. The portability warning that Perl throws has been deliberatly turned off
