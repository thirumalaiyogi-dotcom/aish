#!/data/data/com.termux/files/usr/bin/bash
# aish installer — Termux-ல ஒரே command:
#   curl -sL https://raw.githubusercontent.com/thirumalaiyogi-dotcom/aish/main/install.sh | bash
set -e
REPO="https://raw.githubusercontent.com/thirumalaiyogi-dotcom/aish/main"
echo "🤖 aish install ஆகுது..."
command -v python >/dev/null 2>&1 || pkg install -y python
curl -fsSL "$REPO/aish.py" -o ~/aish.py
curl -fsSL "$REPO/aish_web.py" -o ~/aish_web.py
python -m py_compile ~/aish.py ~/aish_web.py
touch ~/.bashrc
grep -q "alias aish=" ~/.bashrc || echo "alias aish='python ~/aish.py'" >> ~/.bashrc
grep -q "alias aishweb=" ~/.bashrc || echo "alias aishweb='termux-wake-lock; python ~/aish_web.py'" >> ~/.bashrc
[ -d ~/storage/shared ] || termux-setup-storage || true
echo ""
echo "✅ முடிஞ்சது!"
echo "   Termux-ஐ close பண்ணி மறுபடி திறங்க. அப்புறம்:"
echo "   aish      → terminal-ல chat"
echo "   aishweb   → Chrome-ல chat (localhost:8080)"
echo "   முதல் தடவை Gemini API key கேட்கும் (aistudio.google.com → Get API key, இலவசம்)"
