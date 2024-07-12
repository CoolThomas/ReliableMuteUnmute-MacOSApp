<img width="657" alt="Screenshot 2024-07-11 at 20 40 25" src="https://github.com/user-attachments/assets/1edf9da4-fe6f-475e-941a-ae734e6cd816">

# Reliable Mute Unmute - MacOS App

## App Description
**Reliable Mute Unmute** is a simple yet reliable app that runs entirely in the menu status bar at the top of your screen. You can mute/unmute all audio inputs with your favorite shortcut. Change colors.  
Plus, the **Mic Protector feature** can help you identify if NSA/CIA/FBI wants to wiretap your mic by unmuting it. ;)  

Fun Fact - 95% of the code was written by ChatGPT, only a few times had to debug it's halucinations.  

Works only on Apple M processors.

## Features
- **Mute/Unmute all audio inputs in macOS with your keyboard shortcut**
- **Change shortcut to what you need**
- **State of mute/unmute visible all the time in the top menu bar**
- **Any colors you want - Change color indicators for mute and unmute** (text file opens, update hex color value)
- **Toggle color mode to enable transparent background**
- **Mic Protector - makes sure when you switch to Mute with shortcut, you stay Muted**

## Mic Protector
Mic Protector ensures that when you switch to Mute with a shortcut, you stay Muted. If a meeting app (Zoom, MS Teams, etc.) or any other application on your macOS tries to unmute your system audio inputs while you want them to stay muted, you will be protected. 

In this situation, the Mic Protector feature automatically detects the unmute attempt and mutes you again instantly. When such a situation occurs, you will hear a special audio notification to recognize that some process/app tried to unmute you unsuccessfully. The counter of total "Mic Protector Events" is displayed in the context menu, allowing you to check how many such events occurred since the app was launched.

**You want to check if Mic Protector really works?**  
No problemo, go to System Settings -> Sound, mute yourself with a shorcut, and try to change the input volume. You will hear a system sound indicating the Mic Protector event (you are instantly muted again on all audio inputs), and event counter in context menu will increase. 

## Screenshots
<img width="659" alt="Screenshot 2024-07-11 at 20 40 03" src="https://github.com/user-attachments/assets/f4aa7421-0c5b-45e2-bfc9-0a34011aa243">
<img width="659" alt="Screenshot 2024-07-11 at 20 39 46" src="https://github.com/user-attachments/assets/58cbb077-d1a1-4306-b865-53e7483b60f2">
<img width="657" alt="Screenshot 2024-07-11 at 20 40 10" src="https://github.com/user-attachments/assets/21e6bfb8-deee-42a7-80dd-f5dd685d65e1">
<img width="656" alt="Screenshot 2024-07-11 at 20 40 14" src="https://github.com/user-attachments/assets/671f9bd8-fb54-4a5c-a5c9-57c02a63153a">
<img width="657" alt="Screenshot 2024-07-11 at 20 40 25" src="https://github.com/user-attachments/assets/7778b3dd-85a5-434d-bf4c-a532d0eebd32">


## Installation Instructions
1. Download the `.dmg` file.
2. Copy-paste the app to the Applications folder.
3. After launching app the first time, you will need to allow system settings to open apps not signed by Apple. This is a standard procedure, you might need to go to settings -> privacy & security -> open anyway button at the bottom. 
4. Then you system will ask for granting access to Accesibility feature (needed for keyboard shortcuts to work).

**Note:** I have only a personal Apple developer account and do not code commercially. Since Apple charges $99 to Apple sign the apps with their blessing, I would rather give it for free.

## License Information
Distributed under the MIT License. See `LICENSE` for more information.
