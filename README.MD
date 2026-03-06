![Target](https://i.imgur.com/i25zaVv.png)
![Target](https://i.imgur.com/XYcaWXf.png)

**ak47_target** is a highly optimized, universally compatible targeting solution for FiveM. Designed to be a completely seamless, drop-in replacement for `ox_target`, `qb-target`, and `qtarget`, it allows you to upgrade your server's performance without having to rewrite a single export in your existing scripts.

## ✨ Key Features

* **Universal Compatibility:** Native, automatic support for **QBCore**, **ESX**, and **QBX** frameworks.
* **Inventory Integration:** Built-in item checks for **ox_inventory** and QBCore's default inventory.
* **Zero-Config Migration:** Automatically intercepts and translates legacy exports from `qb-target`, `qtarget`, and `ox_target`. Just stop the old script, start this one, and you're done!
* **Advanced Zones:** Create Box, Sphere, and Poly zones with built-in 3D visual debugging (`debug = true`).
* **Infinite Sub-Menus:** Easily nest options inside sub-menus with an automatically generated "Go Back" button for smooth navigation.
* **Extensive Entity Support:** Target specific global models, networked entities, local entities, peds, vehicles, and players.

---

## 📚 Documentation

Detailed API documentation, configuration guides, and code examples are available on our GitBook.

Whether you are adding a simple ATM target, drawing complex polygon zones, or building deep nested menus, the docs have you covered.

👉 **[Read the Official ak47_target Documentation Here](https://docs.menanak47.com/plugins/ak47_target)** 👈

---

## 🛠️ Installation

1. Download the latest release from the repository.
2. Extract the `ak47_target` folder into your server's `resources` directory.
3. Ensure you completely stop and remove any existing targeting scripts (e.g., `qb-target`, `ox_target`).
4. Add `ensure ak47_target` to your `server.cfg`.
5. *Optional:* If you are using scripts that check for the state of old target resources, you can rename the folder to `qb-target` or `ox_target`—the internal exports will still function perfectly.

---

## 💻 Quick Snippet Preview

```lua
-- Add a target to all ATMs
exports.ak47_target:addModel({'prop_atm_01', 'prop_atm_02'}, {
    {
        name = 'use_atm',
        icon = 'fas fa-credit-card',
        label = 'Use ATM',
        distance = 1.5,
        event = 'myBank:client:openMenu'
    }
})
