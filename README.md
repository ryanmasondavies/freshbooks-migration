# freshbooks-migration

Ruby script for migrating Harvest (or CSV formatted) timesheets to FreshBooks.

## Usage

Create your own config file from the example:

```
cd freshbooks-migration
cp config.yml.example config.yml
```

 Then edit the file to include your FreshBooks API key. These are found in your account settings:

 ```
freshbooks_subdomain: "{{SUBDOMAIN}}.freshbooks.com"
freshbooks_auth_token: "{{TOKEN}}"
```

(Replace the text in {{ }} above with the relevant data.)

Export your data from Harvest in CSV format and add it as `data.csv` in the project directory. The format should match that described in `data.csv.example`.

Once the files are configured, run:

```
bundle
ruby migrate.rb
```

If you have any issues, please open a new issue [here](https://github.com/iotize/freshbooks-migration/issues/new) and I'll take a look. :-)
