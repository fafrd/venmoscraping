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
