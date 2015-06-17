Run server

     rackup

Send request

     curl -X POST -H "Content-Type: application/json" -d '@stash-payload-multi.json' http://localhost:9292/stash


Example Stash Payload
---------------------

Following json contains modified stash webook data and contains comments
which makes the JSON invalid...
(note that you have to set feature :force_script enabled to make `scirpt` key
working)

     {

       //addition params (not provided by stash)
       "owner_name": "FINAL-CI",
       ".travis.yml": {
         "language": "bash",
         "script": "sleep 60; echo 'Hi!'",
         "git": {
           "no_clone": true
         }
       },

        // from stash webhook
        "repository":{
           "slug":"test-repo",
           "id":789,
           "name":"test-repo",
           "scmId":"git",
           "state":"AVAILABLE",
           "statusMessage":"Available",
           "forkable":true,
           "project":{
              "key":"FIN",
              "id":676,
              "name":"FINAL-CI",
              "description":"Test framework based on travis-ci",
              "public":false,
              "type":"NORMAL"
           },
           "public":false
        },
        "refChanges":[
           {
              "refId":"refs/heads/master",
              "fromHash":"26889fb199985390da9c668d1399702940c44132",
              "toHash":"08328b76d12e956d96e5e87c1fd7cf34265828ef",
              "type":"UPDATE"
           }
        ],
        "changesets":{
          // omnited, irelevant for travis-listener
        }
     }


You can obtain a multi-branch payload.
For each `refChanges` item (e.g. pushed branch) is called
`Travis::Sidekiq::BuildRequest.perform_async(data)`.

     {
        "repository":{
           "slug":"test-repo",
           "id":789,
           "name":"test-repo",
           "scmId":"git",
           "state":"AVAILABLE",
           "statusMessage":"Available",
           "forkable":true,
           "project":{
              "key":"FIN",
              "id":676,
              "name":"FINAL-CI",
              "description":"Test framework based on travis-ci",
              "public":true,
              "type":"NORMAL"
           },
           "public":true
        },
        "refChanges":[
           {
              "refId":"refs/heads/br",
              "fromHash":"d83821a18d2af9a037b8d81f4f99234aa9f805d2",
              "toHash":"a6656906d4bd0ed38e8dd142f690e74509c63961",
              "type":"UPDATE"
           },
           {
              "refId":"refs/heads/master",
              "fromHash":"c255eafe4e2eb485f83b6ca53f24a81455a1083a",
              "toHash":"0200731dd9ce4b32e6d1df0806bdbcb9e65ef95b",
              "type":"UPDATE"
           }
        ],
        "changesets": {
          //...omnited
        }
     }
