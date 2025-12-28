# DnD-Session-Voting

A website to vote for the next DnD session in the current campaign.



Api Definition



Vote



{

  "id": 1,

  "name": "Max",

  "timeSlotIds": \[3, 5, 7]

}



Timeslot



{

  "id": 5,

  "weekday": "MONDAY",

  "dateTime": "2025-03-17T19:30:00"

}



VotingWeek



{

  "id": 12,

  "deadline": "2025-03-15T23:59:59",

  "timeSlots": \[

    {

      "id": 3,

      "dateTime": "2025-03-18T18:00:00"

    },

    {

      "id": 5,

      "dateTime": "2025-03-20T19:30:00"

    }

  ]

}

