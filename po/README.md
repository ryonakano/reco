# How to Add a Translation of This App

## Fork and Clone the Repository

First of all, fork this repository on GitHub. Next, clone the forked repository to local:

    git clone https://github.com/your-username/writer.git

## Add Your Language Code to LINGUAS Files

Search for your language code (e.g. en = English, zh_CN = Chinese Simplified). See https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes if needed. Then add it to `po/LINGUAS` and `po/extra/LINGUAS`. Please make sure language codes sort alphabetically. For example, if a LINGUAS file contains `ko`, `mr` and `zh_TW`, its content should be sorted like this:

    ko
    mr
    zh_TW

## Translate .po Files

Now what you've been waiting for! Copy `po/com.github.ryonakano.writer.pot` and name `po/<language_code>.po` and copy `po/extra/extra.pot` and name `po/extra/<language_code>.po`. Then translate these created .po files using a .po file editor of your choice (e.g. Poedit). The former file contains strings for the app itself and the latter is for metadata files (.appdata.xml and .desktop files).

## Commit Your Translation Works

After saving the .po files, open a terminal in the folder you've cloned this repository in and type:

    git checkout -b add-translation

Then add the .po files of your language and LINGUAS files. **Do not add other files!**

    git add po/LINGUAS po/extra/LINGUAS po/<language_code>.po po/extra/<language_code>.po

Next, create a commit and push it to your cloned repository on GitHub:

    git commit -m "Add <Language Name> translation"
    git push origin add-translation

Type your GitHub username and password if asked.

Finally, open your cloned repository on GitHub, select "Compare & Pull Request", and create a new pull request.

And that's all! I'll check whether there is no problem in your pull request and if so I'll approve and merge your pull request! Your translation is released every time I release a new version of the app to AppCenter, so it is not always reflected when your pull request is merged. Please be patient.

# How to Update an Existing Translation

You can also create a pull request that updates existing translations. In this case, you don't have to edit LINGUAS files. Open existing .po files with any .po file editor and commit them when completed.

# Note

* **If you find some issue (e.g. typo) in the source strings, create another pull request that fixes it. Do NOT fix it in your translation pull request.** If you don't know how to fix it, create a new issue about it. I'll fix it.
* **If you would like to translate the app into multiple languages, please make separated PRs per languages.** It's not a good thing to include translations of more than 2 languages in your one pull request.
* Edit and commit only `po/LINGUAS`, `po/extra/LINGUAS`, `po/<language_code>.po` and `po/extra/<language_code>.po`. Do NOT include other files in your pull request.

# References

This file was created by referring the following reference:

* https://github.com/lainsce/notejot/blob/master/po/README.md
