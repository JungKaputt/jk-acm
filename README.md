# jk-acm (Advanced Conquest Manager)

**jk-acm** is a high-end territory management system for **QBCore** Framework. It introduces a competitive environment for organizations and gangs to claim, defend, and expand their influence across Los Santos through both static and dynamic methods.

## 🚀 Key Features

* **Static & Dynamic Turfs**: Control pre-defined map locations or deploy your own territory anywhere using a useable Flagpole item.
* **Boss-Only Deployment**: Strategic placement is limited to organization leaders (Grade 5), ensuring high-stakes decision making.
* **Modern Minimalist HUD**: A clean, responsive UI at the bottom of the screen inspired by modern competitive games.
* **Fog of War Mechanics**: Rivals cannot see the territory UI until they physically discover the flagpole and initiate an attack.
* **Anti-Exploit System**: Progress bars will pause or reverse if the player:
    * Is inside a vehicle.
    * Is dead or in a "last stand" state.
    * Leaves the capture radius.
* **Automated Shielding**: Post-capture protection timers to prevent "spawn-camping" of territories.
* **Persistent Database**: Fully integrated with MySQL to save all turf positions and ownership through server restarts.

## 🛠️ Requirements

* [qb-core](https://github.com/qbcore-framework/qb-core)
* [oxmysql](https://github.com/overextended/oxmysql)

## 📋 Installation

1.  **Database**: Import the provided `.sql` file to create the `acm_dynamic_turfs` and `acm_members` tables.
2.  **Item**: Add `territory_flag` to your `shared/items.lua`.
3.  **Config**: Customize radius, capture rates, and models in `config.lua`.
4.  **Start**: Add `ensure jk-acm` to your `server.cfg`.

## 🌐 Support & Community

Join our Discord for updates, support, and community discussions:
* **Discord**: [https://discord.gg/a8X9YYZMkT](https://discord.gg/a8X9YYZMkT)

---
Developed with ❤️ for competitive Roleplay servers.
