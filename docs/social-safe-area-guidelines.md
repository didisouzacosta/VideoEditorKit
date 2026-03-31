# Social Safe Area Baseline

This project now distinguishes between official per-platform guides and a conservative universal social guide for the generic `9:16` preset.

## Official references

- Meta Reels ads guidance: [facebook.com/business/ads/facebook-instagram-reels-ads](https://www.facebook.com/business/ads/facebook-instagram-reels-ads)
- TikTok in-feed ads help: [ads.tiktok.com/help/article/tiktok-auction-in-feed-ads](https://ads.tiktok.com/help/article/tiktok-auction-in-feed-ads?lang=en)
- YouTube Shorts specs: [support.google.com/google-ads/answer/16041697](https://support.google.com/google-ads/answer/16041697?hl=en)
- YouTube official vertical overlay asset: [services.google.com/fh/files/misc/youtubesafezoneoverlay_vertical_final.png](https://services.google.com/fh/files/misc/youtubesafezoneoverlay_vertical_final.png)

## Encoded baselines

- Instagram Reels: `top 250`, `bottom 250`, `left 0`, `right 0` in a `1080x1920` canvas.
- TikTok standard LTR in-feed template: `top 240`, `bottom 660`, `left 120`, `right 120` in a `1080x1920` canvas.
- YouTube Shorts overlay: `top 288`, `bottom 672`, `left 48`, `right 192` in a `1080x1920` canvas.

## Universal social guide

The generic social preset uses the intersection of the three platform guides above. In `1080x1920`, that produces:

- `top 288`
- `bottom 672`
- `left 120`
- `right 192`

This keeps the default `9:16` guide inside the stricter TikTok and YouTube margins while remaining conservative for Reels.
