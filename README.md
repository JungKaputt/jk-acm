# 🕴️ jk-acm (Advanced Criminal Management)

![FiveM](https://img.shields.io/badge/FiveM-Tested-blue)
![QBCore](https://img.shields.io/badge/QBCore-Ready-orange)
![Lua](https://img.shields.io/badge/Language-Lua-green)

**jk-acm** is a highly advanced, interactive Syndicate and Gang Management system designed for the QBCore framework. It goes beyond simple menus, bringing criminal roleplay to the next level with a modern Laptop UI, cinematic blackmarket airdrops, dynamic turf wars, and placeable organization safes.

---

## ✨ Key Features

### 💻 Modern Organization Management (Laptop UI)
* **Create & Manage:** Players can establish their own Syndicates/Organizations for a configurable fee.
* **Rank & Permissions:** A dynamic 5-tier hierarchy system. The Boss can assign custom permissions (Invite, Kick, Promote, Withdraw, Laundry, Blackmarket) to specific ranks.
* **Treasury System:** Integrated organization bank accounts for deposits, withdrawals, and automated tax collection.
* **Activity Logs:** Keep track of who is doing what, including treasury movements, blackmarket purchases, and laundering taxes.
* **Application System:** Unaffiliated players can browse existing syndicates and send applications to join them directly through the UI.

### 🚩 Interactive Turf Wars (Static & Dynamic)
* **Static Turfs:** Pre-defined territories that gangs can fight over and conquer.
* **Dynamic Turfs (Gang Flags):** Bosses can claim their own headquarters by placing a physical flag prop anywhere in the world using an interactive raycast placement system.
* **Advanced War Mechanics:** Real-time zone calculation measuring the ratio of Attackers vs. Defenders inside the zone.
* **Modern HUD:** A sleek, dynamic UI that displays turf status (Secured, Contested, Under Attack), capture progress, and shield timers.
* **Shield Protection:** Captured or successfully defended turfs receive a temporary shield cooldown to prevent constant griefing.

### 🛩️ Cinematic Blackmarket Airdrops
* **Immersive Deliveries:** Purchasing from the Blackmarket triggers a fully networked, cinematic cargo plane that flies over the map to drop the package.
* **Parachute & Flares:** The crate falls with a parachute, detaches upon landing, and pops a flare to signal its location.
* **Smart Cooldowns:** Item-specific cooldowns per organization. Need it faster? Pay the optional **Rush Fee** to bypass the cooldown.

### 💰 Money Laundering Missions
* **Interactive Courier:** Exchange marked bills for clean cash by meeting a randomized NPC contact.
* **Organization Tax:** A configurable percentage of the laundered money is automatically deposited into the organization's treasury as a tax.

### 🧰 Custom Stash & Safes
* **Interactive Placement:** Authorized members can place physical safes anywhere using a smooth raycast positioning system (adjust height and rotation).
* **PIN Code Security:** Safes are secured with a custom 4-digit PIN code set during placement. 

---

## ⚙️ Dependencies

* [qb-core](https://github.com/qbcore-framework/qb-core)
* [oxmysql](https://github.com/overextended/oxmysql) (For database interactions)

---

## 🚀 Installation

1. Download the repository and place the `jk-acm` folder into your server's `resources` directory.
2. Import the provided `.sql` file into your database to create the necessary tables (`acm_organizations`, `acm_members`, `acm_applications`, `acm_logs`, `acm_turfs`, `acm_dynamic_turfs`, `acm_stashes`).
3. Add the required items (e.g., Dynamic Turf Flag, Stash Safe, Dirty Money) to your `qb-core/shared/items.lua`.
4. Ensure you have built the UI (HTML/JS/CSS) if you are working from the source code.
5. Add `ensure jk-acm` to your `server.cfg`.

---

## 📝 Usage & Commands

* **Open Laptop:** Use the command `/criminalphone` (or your configured command/keybind) to open the ACM interface.
* **Join Org:** Use `/joinorg` to accept an incoming syndicate invite.
* **Start Turf War:** Stand inside a rival's static turf zone and type `/turf` to initiate an attack (Dynamic turfs are attacked by interacting with the flag prop).

---

## 👨‍💻 Author

Developed with ❤️ by **JungKaputt (JK)**.
