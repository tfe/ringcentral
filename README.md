[ringcentral](http://github.com/tfe/ringcentral/)
========

A Ruby library for interacting with the RingCentral [RingOut API](https://service.ringcentral.com/ringoutapi/) and (coming soon) [FaxOut API](https://service.ringcentral.com/faxoutapi/).

Currently it is a very thin wrapper around the native RingCentral HTTP API. Eventually I would like to document and abstract away as many of the idiosyncrasies of the native API as possible.

All four RingOut commands are supported (see "Usage" below).


Installation
------------

Install the gem:

    sudo gem install ringcentral

And if you're using Rails (not required), add it to your environment.rb configuration as a gem dependency:

    config.gem 'ringcentral'

I highly recommend requiring a specific version (with the `:version` argument to `config.gem`) from your app, because this gem is young and the API *will* change.



Usage
-----

### RingOut

When calling `list` and `call`, you will always need to supply the RingCentral account credentials as the first three arguments to the methods:

* **Username**: your main RingCentral account phone number
* **Password**: password for an individual user on your RingCentral account
* **Extension**: extension number for an individual user on your RingCentral account

For `status` and `cancel`, no credentials are required by RingCentral, just a session ID returned by the `call` method.

*Errata*

* RingCentral returns a "Call Completed" response for every session ID that's not attached to a call currently in progress.
* The "WS" parameter is returned when placing a call and is accepted as a parameter to the `status` and `cancel` methods, but as far as I can tell it doesn't do anything. RingCentral support didn't know either.


#### List

    RingCentral::Phone.list(username, password, extension)

Gets a hash of the numbers associated with the provided RingCentral credentials (output formatted for readability). Example:

    >> RingCentral::Phone.list('8889363711', '1234', '101')
    => {
         "Home" => "6505553711",
         "Mobile" => "6505551233",
         "Business" => "6505551550"
       }



#### Call

    RingCentral::Phone.call(username, password, extension, to, from, caller_id, prompt = 1)

Place a RingOut call to the `to` number, from the `from` number, and with the specified `caller_id`. Set `prompt` to `0` to avoid the "Press 1 to connect this call" prompt (default is to leave the prompt on).

The response is a session ID (which you can use to get call status or cancel the call later) and a "WS" field (see "Errata" above).

    >> RingCentral::Phone.call('8889363711', '1234', '101', '6505551230', '6505551231', '8889363711')
    => {
         :session_id => "20",
         :ws => ".62"
       }


#### Status

    RingCentral::Phone.status(session_id, ws = nil)

Check the status of the RingOut call with a given `session_id` in progress (or completed). The `ws` parameter appears to be unused, so it defaults to `nil`.

The response is a hash of status information: for the call as a whole, and the status for each of the numbers (callback, the originating number; and destination, the number being called). Possible values for the status are as follows:

* **Success**: picked up, line open (gets set for the callback number before the destination)
* **In Progress**: ringing (or waiting to be rung if it's the destination number)
* **Busy**: appears in the "general call status" field after call has completed
* **No Answer**
* **Rejected**: party hung up, line closed
* **Generic Error**
* **Finished**: other party hung up, line closed
* **International calls disabled**
* **Destination number prohibited**

In general, this is how I've observed call statuses to proceed over the course of the RingOut procedure:

When the call is initiated, the callback number is called. All statuses are "In Progress."

    >> RingCentral::Phone.status(3)
    => {
         :general     => "In Progress",
         :callback    => "In Progress",
         :destination => "In Progress"
       }

When the call to the callback number is picked up, that status goes to "Success." It will remain this way during the time it takes for the operator to respond to the call connection prompt, if you did not skip it.

    >> RingCentral::Phone.status(3)
    => {
         :general     => "In Progress",
         :callback    => "Success",
         :destination => "In Progress"
       }

When the destination number is picked up, all statuses go to "Success." They will remain this way while the call is in progress.

    >> RingCentral::Phone.status(3)
    => {
         :general     => "Success",
         :callback    => "Success",
         :destination => "Success"
       }

When both calls (to the callback and the destination numbers) have completed, the final statuses are "Call Completed." They will remain this way for a couple seconds.

    >> RingCentral::Phone.status(3)
    => {
         :general     => "Call Completed",
         :callback    => "Call Completed",
         :destination => "Call Completed"
       }

Edge cases: I haven't experimented with many cases, but as an example this is the status returned when the callback number rejects the call.

    >> RingCentral::Phone.status(6)
    => {
         :general     => "Busy",
         :callback    => "Rejected",
         :destination => "Generic Error"
       }


#### Cancel

    RingCentral::Phone.cancel(session_id, ws = nil)

Cancel a RingOut call with a given `session_id`. It seems like you can only cancel while one of the numbers is still ringing, or perhaps only when the callback number is being rung. You cannot cancel a call that has been picked up and is running.

The response is simply the session ID in a hash. The same response is given no matter what the result of the API call was. Essentially this method could be considered to make a "best effort" attempt to cancel your call, but don't rely on it.

    >> RingCentral::Phone.cancel(242323)
    => { :session_id => "242323" }


### FaxOut

To be implemented.


Todo
----

* Be able to supply RingCentral account credentials once, up-front, rather than supplying with each API call.
* Wrap up the call, status, and cancel into a Call object which maintains its state.
* Set Call command arguments using response from the List command, perhaps so a user could do `call(:from => :mobile)`
* Determine how accepting the RingCentral APIs are of formatted or malformed input.
* Implement the FaxOut API.
* Write tests.


Contact
-------

Problems, comments, and pull requests all welcome. [Find me on GitHub.](http://github.com/tfe/)


Copyright
-------

Copyright © 2010 [Todd Eichel](http://toddeichel.com/) for [Fooala, Inc.](http://opensource.fooala.com/).
