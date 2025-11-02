#!/bin/bash
# Remove unnecessary Docker files before pushing to GitHub

echo "Cleaning up Docker files..."

# Remove Docker files
rm -f docker-compose.yml
rm -f Dockerfile
rm -f entrypoint.sh
rm -f setup.sh
rm -f README-KALI.md

# Remove old files
rm -rf torproxy/old/
rm -f structure.md
rm -f torproxy/notes.md
rm -f torproxy/torproxy.sh

# Remove IDE settings
rm -rf .vscode/

# Remove compiled binaries (will be rebuilt)
rm -f macChanger/macChange
rm -f torproxy/torproxy.so
rm -f macChanger/*.o
rm -f torproxy/*.o

echo "✓ Cleanup complete!"
echo
echo "Files ready for GitHub:"
echo "  - macChanger/ (source + Makefile)"
echo "  - torproxy/ (source + Makefile)"
echo "  - INSTALL.sh"
echo "  - run.sh"
echo "  - torrc"
echo "  - README.md"
echo "  - .gitignore"
