# Transmog Hub — Changelog

## 1.14.0
- **One rating is now enough to enter the chart** while the community is small. The rating formula stays the same, so an outfit with a single five-star rating sits near the middle, and outfits with many good ratings still rank higher. As more players join, the bar rises on its own.
- **"New" and "Recommended" now show outfits from the last 60 days** instead of 14, so new outfits stay visible longer.
- **"Trending" now counts stars from the last 30 days** instead of 7.

## 1.13.3
- Small fix for players in both Europe and the Americas: the daily "I'm online" check-in now happens once a day in each region.

## 1.13.2
- If you play in both Europe and the Americas, the addon now keeps the network data of each region separately, so players and outfits from one region no longer mix into the other.

## 1.13.1
- The outfit catalogue that comes with updates is getting ready to include outfits from both Europe and the Americas.
- When looking for other players to connect to, the addon now only tries players in your own region.

## 1.13.0
- **Left-click an item** in an outfit to take it off the preview model, and click again to put it back. Handy for seeing how an outfit looks without a cloak, helm or weapon. The outfit itself doesn't change.
- **Ctrl+Left-click an item** to try it on your own character in the game's dressing room. Ctrl+click more items to add them on top.

## 1.12.1
- Ready for patch 12.1.7: the addon is marked as up to date for it.

## 1.12.0
- **Where to find items, without AllTheThings.** The addon now has its own copy of item sources from the AllTheThings database, so tooltips show where to get almost every item with an appearance: zone or dungeon, boss, vendor, quest, treasure, achievement or profession, plus coordinates and price.
- Right-click an item to drop a map pin with these coordinates.
- The data ships as a small extra addon, Transmog Hub - Sources, that loads only when needed. Keep both folders in your AddOns folder.
- If AllTheThings is installed, its live data is still used first.
- Item source data: AllTheThings (MIT license). Thank you to the ATT team!

## 1.11.0
- **A much faster network.** Players now swap short lists of what they have, and the addon downloads only the outfits you are missing. Outfits that came with the addon update are never downloaded again.
- New outfits download from up to three players at once.
- An outfit linked in chat is fetched first, ahead of everything else.
- The status bar shows how many outfits are still downloading.

## 1.10.0
- **Phonebook.** Once a day the addon checks in on the network with your character name and faction. Players who are alone use these check-ins to reach someone who is actually online, and new players get them with addon updates.
- `/thub net` shows how many players with the addon were online in the last two weeks.
- You can opt out with `/thub phonebook off` or in Settings → Privacy. Your entry then expires within two weeks.

## 1.9.0
- **A much bigger catalogue in every update:** up to 2000 recent outfits from the last 90 days, not just the chart and the Hall of Fame. New players see almost the whole network from the very first launch.
- **The catalogue now knows who was online recently.** If nobody around you has the addon, it first reaches out to players of your faction who were active in the last two weeks, so you join the network much faster.

## 1.8.1
- Smarter introductions: contacts passed between players now carry their faction, so the addon no longer tries to reach players of the other faction. From cross-faction groups it only remembers players of your own faction.

## 1.8.0
- **Faster connections.** The addon remembers players you met who have it and reconnects to them right after you log in. Players you meet pass a few of their contacts to each other, so the network links up much faster.
- It also quietly gets in touch with players you whispered or grouped with. Players without the addon see nothing.
- **Share in chat.** Right-click an outfit to put a ready-made line about it into your chat box. You send it yourself. Players with the addon see a clickable link that opens the outfit; if they don't have it yet, the addon asks you for it and opens it when it arrives.
- New achievements: "Word of Mouth" for sharing an outfit in chat, plus "The Grapevine" and "Runway Ambassador" for players you talked to who installed Transmog Hub.

## 1.7.0
- Outfit names written in Cyrillic are shown in Latin letters on non-Russian game clients ("Ядовитый" → "Yadovityy"), so everyone can read them. The original name is kept.
- Search finds outfits by both the original and the Latin spelling.

## 1.6.0
- **Spanish language** for Spain and Latin America (esES and esMX): the whole interface, help, tour, achievements and tags.
- Hidden achievements have Spanish texts, and some of them nod to Spanish-speaking WoW creators.
- The name filter now also catches Spanish profanity.
- Outfit names keep accented capitals right (Ñ, Á, Ü…).
- With a Spanish game client, the font check also requires á é í ó ú ü ñ ¿ ¡.

## 1.5.0
- **Where to find every item.** The item tooltip now shows where to get it: zone, vendor or quest, coordinates and price.
  - With **AllTheThings** installed, the data comes from its database.
  - Without it, the data comes from what other players have spotted. The addon notes items with appearances at vendors, in loot and in quest rewards, and the daily catalogue update shares the results with everyone.
  - You can turn this off with `/thub sources off` or in Settings → Privacy.
- **Show on map.** Right-click an item to place a map pin. The chat gets a clickable map link. TomTom is used if installed.

## 1.4.0
- **Meet players through the catalogue.** If nobody around you has the addon, it quietly gets in touch with recent outfit authors of your faction on other realms, and you join the network through them.
- `/thub knock` checks this by hand, and `/thub net` shows who you met this way.
- Smarter cleanup of the outfit database. Outfits from the chart, the Hall of Fame, your own, your favourites and your followed authors are always kept.

## 1.3.0
- Each network icon in the status bar has its own tooltip, and a new icon shows guildmates with the addon.
- Lists scroll smoothly, without arrows or page buttons.
- The outfit card shows its place in Best and Trending.
- A tidier close button.
- A new hidden achievement.

## 1.2.0
- **Outfit catalogue in every update.** Chart outfits, the Hall of Fame and fresh outfits come with the addon, so there is always something to browse.
- Outfits also travel through your guild.

## 1.1.0
- **English language.** The addon follows your game client language.

## 1.0.0
- First release.
