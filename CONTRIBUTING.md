# Contributing

There are many ways you can contribute, even if you don't know how to code.

## Reporting Bugs or Suggesting Improvements

Simply [create a new issue](https://github.com/ryonakano/reco/issues/new) describing your problem and how to reproduce or your suggestion. If you are not used to do, [this section](https://elementary.io/docs/code/reference#reporting-bugs) is for you.

## Writing Some Code

We follow the [coding style of elementary OS](https://elementary.io/docs/code/reference#code-style) and [its Human Interface Guidelines](https://elementary.io/docs/human-interface-guidelines#human-interface-guidelines) in our code, please try to respect them.

## Translating This App

### Fork and Clone the Repository

First of all, fork this repository on GitHub. Next, clone the forked repository to local:

    git clone https://github.com/your-username/reco.git

### Add Your Language Code to LINGUAS Files

Search for your language code (e.g. en = English, zh_CN = Chinese Simplified). See https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes if needed. Then add it to `po/LINGUAS` and `po/extra/LINGUAS`. Please make sure language codes sort alphabetically. For example, if a LINGUAS file contains `ko`, `mr` and `zh_TW`, its content should be sorted like this:

    ko
    mr
    zh_TW

### Build the App and Update Translation Files

After that, run the following command to create PO files:

    meson build --prefix=/usr
    cd build/
    ninja com.github.ryonakano.reco-update-po
    ninja extra-update-po

Other language files are also updated when you run this command, but **ignore them.**

### Translate PO Files Generated

Now what you've been waiting for! Translate `po/<language_code>.po` and `po/extra/<language_code>.po` using a PO editor of your choice (e.g. Poedit).

### Commit Your Translation Works

After saving the PO files, open a terminal in the folder you've cloned this repository in and type:

    git checkout -b <branch-name>

Then add the PO files in your language and LINGUAS files. **Do not add other files!**

    git add po/LINGUAS po/extra/LINGUAS po/<language_code>.po po/extra/<language_code>.po

Next create a commit and push it to your cloned repository on GitHub:

    git commit -m "Add <Language Name> translation"
    git push origin master

Type your GitHub username and password if asked.

Finally, open your cloned repository on GitHub, select "Compare & Pull Request", and create a new pull request.

And that's all! I'll check whether there is no problem in your pull request, and if so I'll approve and merge your pull request! Your translation is released every time I push the app to AppCenter, so it is not always reflected when your pull request is merged. Please be patient.

### How to Update Existing Translation

You can also update existing translation and create a pull request. In this case, you don't have to edit LINGUAS files. Open existing PO files with any PO editor and commit them when completed.

### Note

* **If you find some issue (e.g. typo) in the source strings, create another pull request which fix it! Do NOT fix it in your translation pull request!** If you don't know how to fix it, create a new issue about it. I'll fix it.
* **If you would like to translate the app into multiple languages, please make separated PRs per languages!** It's not good thing to include more than two translation in your one pull request.
* Edit and commit only `po/LINGUAS`, `po/extra/LINGUAS`, `po/<language_code>.po` and `po/extra/<language_code>.po`. Do NOT include other files in your pull request.
* If you have some knowledge of meson and ninja, it's recommended to check your translation works by building the app.

## References

This file was created by referring the following reference:

* https://github.com/lainsce/notejot/blob/master/po/README.md
