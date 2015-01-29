## SearchMe

Interactive programming exercise for building a simple text index and
query server.

### To install the gem

the gem `specific_install` allows you to install 'edge' versions of gems
from github. install it, and use it to install `search_me` from the
source in this repositiory:

```
gem install specific_install
gem specific_install https://github.com/worace/search_me
```

### Word sanitization

To make things more consistent, the server expects words to be
separated and tokenized based on the following rules:

* Words should be separated by the characters: `" ", "-", "—"`
* Words should be downcased when indexed.
* Non-word characters (`\W` in perl-style regexes) and `"_"` characters
  should be removed from each word

### CLI

Start a session with the executable `search_me`; it requires 1 command
line arg, the host where your server is running.

For example

```
search_me http://localhost:9292
```

The gem will run a search and index session against the specified host,
expecting it to adhere to the HTTP api outlined below.

### Expected Server API

* `POST /index` -- file upload

must receive text files as uploads and index them.

query params:

`[file][filename]` -- string name of file to include in
index

`[file][tempfile]` -- path where upload is stored


* `POST /query` -- search endpoint

param: `query` -- string of word to search for

__Expected response:__ JSON array of occurrences in the previously
indexed text. Format: "filename:line-number:word-number". EG:
`file1.txt:125:5`. Line and word counts are 1-based, not 0-based.

