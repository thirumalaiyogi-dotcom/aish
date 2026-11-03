# 🤖 aish — தமிழ் AI Assistant for Termux

உங்க Android phone-ல தமிழ்ல பேசுற AI assistant. நீங்க கேளுங்க → AI command தரும் → நீங்க ✅ சொன்னா மட்டும் run ஆகும் → output-ஐ படிச்சு AI அடுத்த step சொல்லும்.

## Install (ஒரே command)

1. [Termux](https://f-droid.org/packages/com.termux/)-ஐ F-Droid-லிருந்து install பண்ணுங்க.
2. Termux-ல இதை run பண்ணுங்க:

```bash
curl -sL https://raw.githubusercontent.com/thirumalaiyogi-dotcom/aish/main/install.sh | bash
```

3. Termux-ஐ close பண்ணி மறுபடி திறங்க.

## 📱 Android App (Termux தேவையில்ல)

**Download:** https://github.com/thirumalaiyogi-dotcom/aish/releases/latest/download/aish.apk

- Email code வச்சு login
- AI key server-ல (Supabase Edge Function) மறைச்சு வச்சிருக்கு — users-க்கு key தேவையில்ல
- ஒவ்வொருத்தருக்கும் தினசரி limit (default 40), chat history save ஆகும்
- Phone-ல இருக்கும் `/system/bin/sh` வழியா commands ஓடும் (Termux tools இல்ல)

Backend: `supabase/schema.sql` (SQL Editor-ல run பண்ணுங்க), `supabase/functions/aish-ask/index.ts` (Edge Function), secret `GEMINI_API_KEY`.

## பயன்படுத்த (Termux)

| Command | என்ன செய்யும் |
|---|---|
| `aish` | Terminal-ல chat |
| `aishweb` | Chrome-ல chat screen (`localhost:8080`) |
| `aish-sort` | Images, videos, PDF-ஐ AI பார்த்து "இது எதுக்கானது"-னு சொல்லி வகை வாரியா பிரிக்கும் |

### aish-sort

```bash
aish-sort                                   # Download folder
aish-sort ~/storage/shared/DCIM/Screenshots # வேற folder
aish-sort FOLDER --max 20                   # ஒரு தடவைக்கு 20 files மட்டும் AI-க்கு
aish-sort FOLDER --no-ai                    # AI இல்லாம, பெயர்/type வச்சு மட்டும்
```

- வகைகள்: Bills, IDs/Certificates, Posters, Screenshots, Personal photos, Forwards/Memes, Study notes, Work documents
- ID cards, bank details போன்றவை `Private` folder-க்கு போகும்
- முழு list `Documents/aish_sort_report.csv`-ல save ஆகும்; ஒருமுறை பார்த்ததை மறுபடி AI-க்கு அனுப்பாது
- எதுவும் delete ஆகாது; ஒவ்வொரு run-க்கும் `~/aish_sort_undo/` folder-ல தனி undo script save ஆகும்
- ⚠️ படங்களோட சின்ன preview AI-க்கு (Google) போகும் — personal folders-ல கவனம்
- Video-க்கு: `pkg install ffmpeg`

முதல் தடவை **Gemini API key** கேட்கும் — [aistudio.google.com](https://aistudio.google.com) → Get API key (இலவசம்).

Claude-க்கு மாற: `echo 'export AISH_PROVIDER=claude' >> ~/.bashrc`

## Safety

- 🟢 பார்க்க மட்டும் · 🟡 மாற்றம் செய்யும் · 🔴 நிரந்தர மாற்றம் (`yes` type பண்ணணும்)
- Risk நிறத்தை AI மட்டும் முடிவு பண்ணாது — code-உம் தனியா check பண்ணும் (`rm`, `find -delete`, `| bash` போன்றவை எப்போதும் 🔴)
- Command output-க்குள்ள இருக்கும் "instructions"-ஐ AI பின்பற்றாது
- `rm -rf ~` போன்ற ஆபத்தான commands தானா block ஆகும்
- AI நேரடியா delete பண்ணாது — முதல்ல `_to_delete` folder-க்கு move பண்ணும்
- எல்லா commands-ம் `~/aish_log.txt`-ல பதிவாகும்

## Tips

- `aishweb` பயன்படுத்தும்போது Termux-ஐ Battery → **Unrestricted** ஆக்குங்க
- Free tier-ல உங்க data Google-ஆல பயன்படுத்தப்படலாம் — sensitive folders-ஐ scan பண்ணாதீங்க

---
Made with ❤️ by Thiran AI Academy
