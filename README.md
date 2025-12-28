# DnD-Session-Voting

A website to vote for the next DnD session in the current campaign.



Api Definition



Vote



{

&nbsp; "id": 1,

&nbsp; "name": "Max",

&nbsp; "timeSlotIds": \[3, 5, 7]

}



Timeslot



{

&nbsp; "id": 5,

&nbsp; "weekday": "MONDAY",

&nbsp; "dateTime": "2025-03-17T19:30:00"

}



VotingWeek



{

&nbsp; "id": 12,

&nbsp; "deadline": "2025-03-15T23:59:59",

&nbsp; "timeSlots": \[

&nbsp;   {

&nbsp;     "id": 3,

&nbsp;     "weekday": "TUESDAY",

&nbsp;     "dateTime": "2025-03-18T18:00:00"

&nbsp;   },

&nbsp;   {

&nbsp;     "id": 5,

&nbsp;     "weekday": "THURSDAY",

&nbsp;     "dateTime": "2025-03-20T19:30:00"

&nbsp;   }

&nbsp; ]

}

