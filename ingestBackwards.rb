#!/usr/bin/ruby

require 'sequel'
require 'pry'
require 'net/http'
require 'json'

DB = Sequel.connect('postgresql://localhost/venmo', :user=>'venmo', :password=>'bitcoin is better')

#url = 'https://api.venmo.com/v1/stories?before_id=2530165445323915469&limit=50'
url = 'https://api.venmo.com/v1/stories?before_id=2529144376727175237&limit=50'

until url.nil?
	puts "requesting " + url
	uri = URI(url)
	response = nil
	loop do
		response = Net::HTTP.get(uri)
		break if response.start_with?('{') # break on success
		puts 'Received "too many requests"... wait and retry'
		sleep(2)
	end
	currentjson = JSON.parse(response)
	url = currentjson['pagination']['next']

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

	batchhash.each {|x| 
		begin
			DB[:transactions].insert(x)
		rescue Sequel::UniqueConstraintViolation => e
			puts e
		end
	}
end

