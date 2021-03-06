# Pinboard RSS to Podcast

## Usage

Create a pinboard feed where each url is an audio file, for example by tagging all relevant urls with `podcast`.
Next, log into pinboard and get your rss url by first selecting the tag
`podcast` and then clicking on RSS.

The resulting feed (e.g. `https://feeds.pinboard.in/rss/secret:<your-key>/u:<your-username>/t:podcast`) is the input for this web service.
Simply use the part behind `rss/` as the path on the pinboard-rss-to-podcast service:
`https://<webservice>/secret:<your-key>/u:<your-username>/t:podcast`.
The webservice will convert the pinboard feed to something a podcast client can understand.
The title and description of each item are the same as in pinboard, author information is taken from the title component behind `|`, if any.

## Known Issues

- Only mp3 is supported right now.
- The Podcast has no image. Possibly set to pinboard logo if that's legally ok and everything.
- As pinboard does not contain an author field, the author is extracted from the
  component after `|` in the title, if that exists.
- Episodes do not have an `guid` attribute because I couldn't be bothered.
