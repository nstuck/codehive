# Uninstalling

```bash
codehive uninstall            # or ./uninstall.sh from a clone
codehive uninstall --purge    # also remove the config and the launcher folder
```

Run it from SSH or a console, not from a Claude session, because it stops the server that session runs on. This stops every server and removes exactly the files the installer recorded. Your project folders are not touched.
