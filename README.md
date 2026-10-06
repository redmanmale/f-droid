# redmanmale F-Droid

A binary F-Droid repository of official [v2rayNG](https://github.com/2dust/v2rayNG) GitHub releases (`com.v2ray.ang`). The APKs keep the upstream signing key, so the client updates an install from GitHub Releases. It does not update the F-Droid.org build (`com.v2ray.ang.fdroid`).

The public address lives in one field, `repo_url` in [`fdroid/config.yml`](fdroid/config.yml). It is currently `https://redmanmale.github.io/f-droid/repo`. GitHub Actions runs on every push to master and once a day, takes the latest non-draft release, verifies the GPG signatures, signs the index with the existing repository key, and deploys the site to GitHub Pages.

## Add the repository

After the first successful deploy, open the [repository page](https://redmanmale.github.io/f-droid/). It contains the add-repo link and the fingerprint. Until the key exists and the workflow has run, that page is empty.

## One-time setup

1. `keytool` from a JDK is required. Run [`scripts/init-keystore.ps1`](scripts/init-keystore.ps1). It creates `secrets/keystore.p12`, writes the fingerprint to `fdroid/fingerprint.txt`, and prints the secret values. Keep the keystore and the password offline as well: if the GitHub secret is lost, the fingerprint changes and clients have to add the repository again.
2. In GitHub: **Settings → Secrets and variables → Actions → New repository secret**.
   - `FDROID_KEYSTORE_BASE64` — the contents of `secrets/FDROID_KEYSTORE_BASE64.txt` (`keystore.p12` encoded as base64).
   - `FDROID_KEYSTORE_PASS` — the password printed by the script.
3. Commit `fdroid/fingerprint.txt`.
4. **Settings → Pages**: set Source to **GitHub Actions**.
5. **Actions → Publish F-Droid repo → Run workflow**. After it succeeds, check the landing page and the index file under `https://redmanmale.github.io/f-droid/repo/` (`index-v1.jar` or `index-v2.json`).

Each run re-enables this workflow so GitHub does not turn the daily schedule off after 60 days without commits. That call uses the built-in `GITHUB_TOKEN`. If GitHub has already disabled the schedule, turn the workflow back on once under Actions; the next run keeps it alive again.

Do not run `fdroid init`. It creates a new key and changes the fingerprint.

## Custom domain

The key and the fingerprint stay the same. The client remembers the URL it was added with, so attach the domain before anyone starts using the repository.

1. Change `repo_url` in `fdroid/config.yml` to `https://<domain>/repo`.
2. Put the domain in `site/CNAME` (one line, without `https://`). Without that file the next deploy clears the custom domain in the GitHub settings.
3. DNS: a CNAME to `redmanmale.github.io` for a subdomain, or GitHub Pages A/AAAA records for an apex domain.
4. **Settings → Pages**: set the custom domain and wait for HTTPS. Do not add the repository to a client until the certificate is ready.
