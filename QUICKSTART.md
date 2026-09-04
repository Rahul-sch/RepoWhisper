# Quick start

1. Install Xcode 15+ and Python 3.12.
2. Create `backend/.venv` and install `backend/requirements.txt`.
3. Run `frontend/setup_xcode.sh` and open the generated Xcode project.
4. Build and run the `RepoWhisper` scheme.
5. Add a repository in the app and choose an indexing mode.
6. Allow microphone access, then press `Cmd+Shift+R` and ask a question.

The macOS app launches and authenticates its own local backend over a Unix-domain socket. No login, remote database, or manually launched web server is required.
