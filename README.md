# 🤖 aish — தமிழ் AI Assistant for Termux

உங்க Android phone-ல தமிழ்ல பேசுற AI assistant. நீங்க கேளுங்க → AI command தரும் → நீங்க ✅ சொன்னா மட்டும் run ஆகும் → output-ஐ படிச்சு AI அடுத்த step சொல்லும்.

## Install (ஒரே command)

1. [Termux](https://f-droid.org/packages/com.termux/)-ஐ F-Droid-லிருந்து install பண்ணுங்க.
2. Termux-ல இதை run பண்ணுங்க:

```bash
curl -sL https://raw.githubusercontent.com/thirumalaiyogi-dotcom/aish/main/install.sh | bash
```

3. Termux-ஐ close பண்ணி மறுபடி திறங்க.

## பயன்படுத்த

| Command | என்ன செய்யும் |
|---|---|
| `aish` | Terminal-ல chat |
| `aishweb` | Chrome-ல chat screen (`localhost:8080`) |

முதல் தடவை **Gemini API key** கேட்கும் — [aistudio.google.com](https://aistudio.google.com) → Get API key (இலவசம்).

Claude-க்கு மாற: `echo 'export AISH_PROVIDER=claude' >> ~/.bashrc`

## Safety

- 🟢 பார்க்க மட்டும் · 🟡 மாற்றம் செய்யும் · 🔴 நிரந்தர மாற்றம் (`yes` type பண்ணணும்)
- `rm -rf ~` போன்ற ஆபத்தான commands தானா block ஆகும்
- AI நேரடியா delete பண்ணாது — முதல்ல `_to_delete` folder-க்கு move பண்ணும்
- எல்லா commands-ம் `~/aish_log.txt`-ல பதிவாகும்

## Tips

- `aishweb` பயன்படுத்தும்போது Termux-ஐ Battery → **Unrestricted** ஆக்குங்க
- Free tier-ல உங்க data Google-ஆல பயன்படுத்தப்படலாம் — sensitive folders-ஐ scan பண்ணாதீங்க

---
Made with ❤️ by Thiran AI Academy
