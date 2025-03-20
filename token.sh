curl 'https://api.swag.live/auth/tokens' \
  -X 'POST' \
  -H 'accept: */*' \
  -H 'accept-language: zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7' \
  -H 'authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImtpZCI6IjBjOTNkZTgzIn0.eyJqdGkiOiJmbmU2TWRST0pFQnBJMEZQIiwiaXNzIjoiYXBpLnN3YWcubGl2ZSIsImF1ZCI6ImFwaS5zd2FnLmxpdmUiLCJzdWIiOiI2N2NlYWJlY2M4MmI4ZmQ2Y2Y2M2Q2ZDYiLCJpYXQiOjE3NDIzNjc0NDEsInNjb3BlcyI6WyItREVGQVVMVCIsInRva2VuOnJlZnJlc2giXSwidmVyc2lvbiI6MiwibWV0YWRhdGEiOnsiY2xpZW50X2lkIjoiYWM5Y2Q0MmItMjk4Mi00MzBmLWJkZDAtMThiMGNlNTA1ZDBhIiwiZmluZ2VycHJpbnQiOiJkMjc5M2RkNCIsIm9yaWdpbmFsIjp7ImlhdCI6MTc0MjM2NzQ0MSwibWV0aG9kIjoiZ29vZ2xlLW9hdXRoMiJ9LCJ1c2VyX2FnZW50Ijp7ImZsYXZvciI6InN3YWcubGl2ZSJ9fX0.wro-WsAlIbQmUXIVAGxZvGQV15HLJsU7RnMskhQ_x6Q' \
  -H 'content-length: 0' \
  -H 'origin: https://swag.live' \
  -H 'priority: u=1, i' \
  -H 'referer: https://swag.live/' \
  -H 'sec-ch-ua: "Chromium";v="134", "Not:A-Brand";v="24", "Google Chrome";v="134"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'sec-fetch-dest: empty' \
  -H 'sec-fetch-mode: cors' \
  -H 'sec-fetch-site: same-site' \
  -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36' \
  -H 'x-client-id: ac9cd42b-2982-430f-bdd0-18b0ce505d0a' \
  -H 'x-session-id: 735e0ebe-e7ac-4624-bf9c-ccdcaf37822f' \
  -H 'x-track: ga_GNMH147MCG=GS1.1.1742367375.5.1.1742367377.58.0.0;mixpanel_distinct_id=$device:195ad30c37e8247-0cd679eb59bdbc-1b525636-16a7f0-195ad30c37e8247;utm_campaign=tw_routine;utm_content=brand;utm_medium=cpc;utm_source=google_g;utm_term=swag' \
  -H 'x-version: 3.223.1'

# !!! I STUCK HERE !!!
# Question: I successfully parse the refresh token, but signer decode failed?
# Cause: SECRET_KEY generated randomly everytime container reload ()
