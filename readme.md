# scraping an api with ruby
The following is an example of scraping a public JSON api using ruby, and storing this data in a postgres database.

I thought scraping Venmo would be a nice exercise after I saw a few news articles about how creepy the venmo public api is. You can access their public api at [https://venmo.com/api/v5/public](https://venmo.com/api/v5/public). I have a nicely formatted example of this data in [example.json](example.json).

I'll walk through the code here. it's not too complicated.

## first, create a database
The file [transactionsTable.sql](transactionsTable.sql) contains a query to make a new table with the needed columns


    create table transactions (
        id text PRIMARY KEY,
        sender_firstname text,
        sender_lastname text,
        sender_username text,
        sender_picture text,
        receiver_firstname text,
        receiver_lastname text,
        receiver_username text,
        receiver_picture text,
        date_created timestamp,
        message text
    );

Assuming you have postgres set up and configured with a user, log in as this user and run this query from file using \i

    \i transactionsTable.sql

The database is empty now, but when it's populated you can grab the most recent 10 rows using this query

    select * from transactions order by date_created desc limit 10;

## next, scrape it
Starting at the top of [ingestBackwards.rb](ingestBackwards.rb)...

Force this file to be executed with ruby

    #!/usr/bin/ruby


Import packages we need. (you'll need to install these using gem first).

    require 'sequel'
    require 'pry'
    require 'net/http'
    require 'json'

Connect to the database using the sequel package, and using the user account set up in postgres.

    DB = Sequel.connect('postgresql://localhost/venmo', :user=>'venmo', :password=>'bitcoin is better')

Set the URL. The parameters here mean we want everything before venmo id 2529144376727175237, and want the max amount they'll give us at once (50 entries)

    url = 'https://api.venmo.com/v1/stories?before_id=2529144376727175237&limit=50'

Start our loop. Run until url is nil (meaning something went wrong. it shouldn't get set to nil.)

Print out "requesting {url}" to the log, so I know something is actually happening. And parse our url string into a URI object.

    until url.nil?
        puts "requesting " + url
        uri = URI(url)
        response = nil

The inner loop here will try venmo's api, repeating until we get a success response. (Venmo started throttling the shit out of me after a day of requests... this is  a hack to keep going.)

    loop do
        response = Net::HTTP.get(uri)
        break if response.start_with?('{') # break on success
        puts 'Received "too many requests"... wait and retry'
        sleep(2)
    end

Use the json package to parse the response, and pull out the url for the next page of results.

    currentjson = JSON.parse(response)
    url = currentjson['pagination']['next']

Now here is where the real magic happens. For each row that has a payment status of "settled", use the map function to place these rows into a ruby hash.

    batchhash = currentjson['data'].select{|row| !row['payment'].nil?}.select{|row| row['payment']['status'] == 'settled'}.map{|row| {
        id: row['payment']['id'],
        sender_firstname: row['payment']['target']['user']['first_name'],
        sender_lastname: row['payment']['target']['user']['last_name'],
        sender_username: row['payment']['target']['user']['username'],
        sender_picture: row['payment']['target']['user']['profile_picture_url'],
        receiver_firstname: row['payment']['actor']['first_name'],
        receiver_lastname: row['payment']['actor']['last_name'],
        receiver_username: row['payment']['actor']['username'],
        receiver_picture: row['payment']['actor']['profile_picture_url'],
        date_created: row['date_created'],
        message: row['note']
    }}

And now for each entry in the hash, insert this into the database. (I could be a bit more clever and set up a batch insert operation, but this is not the bottleneck, so why bother.)

    batchhash.each {|x|
        begin
            DB[:transactions].insert(x)
        rescue Sequel::UniqueConstraintViolation => e
            puts e
        end
    }

Finally, end the loop and make another request using the new url.

    end
