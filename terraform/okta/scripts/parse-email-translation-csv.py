#!/usr/bin/env python3

import csv, os, sys, yaml
from itertools import groupby

if len(sys.argv) != 2:
    raise "Need 1 argument, name of the translation csv file"

filename = sys.argv[1]

# read the whole csv file into a str[][]
with open(filename) as csvfile:
    reader = csv.reader(csvfile, delimiter=';')

    rows = [row for row in reader]
    # TODO better csv parsing
    # [x] remove empty lines (we ignore them)
    # [ ] check the file dimensions
    # [ ] empty cells
    # remove rows with empty B column. also remove A and C columns
    rows = [row for row in rows if row[0] != '']

# transform csv into { <language code>: { <translation key>: <translation> } }, dict of dictionaries
translations = {}
for lang_idx in range(2, len(rows[0])):
    lang_code = rows[0][lang_idx]

    # don't add rows with a space in it
    translations[lang_code] = {row[0]: row[lang_idx] for row in rows if ' ' not in row[0]}
    translations[lang_code]["languageCode"] = lang_code

for lang_code, translation_texts in translations.items():
    # translations with no '_' in their translation keys, which are the ones to be added in all emails
    generic_translations = {key: value for key, value in translation_texts.items() if '_' not in key}

    # translations with '_' in them
    # translation keys are parsed as `<email template name>_<key in the yaml file>` below
    file_specific_translations = [[key, value] for key, value in translation_texts.items() if '_' in key]

    # create a dictionary as
    #   { <email template name>: [[<email template name>, <translation key 1>, <translation 1>] ... ] }
    # for the language `lang_code`. The format isn't final, will be fixed below
    translation_files = [[key[0:key.find('_')], key[key.find('_')+1:], value] for key, value in file_specific_translations]
    translation_files = sorted(translation_files, key=lambda x: x[0])
    translation_files = {template_name: list(translations) for template_name, translations in groupby(translation_files, lambda x: x[0])}

    # create a separate translation yaml file for each email template
    for translation_file in translation_files.keys():
        # create translation file as
        #   { <translation key 1> : <translation 1> ... }
        # which is the format we need in yaml file
        translations_file_content = {translation_key: translation for [_, translation_key, translation] in translation_files[translation_file]}
        # merge with generic translations
        translations_file_content.update(generic_translations)

        # make sure the directory of new yaml file exists
        if not os.path.exists(f'settings/emails/{translation_file}'):
            os.makedirs(f'settings/emails/{translation_file}')
        
        # create the yaml file
        with open(f'settings/emails/{translation_file}/translations/{lang_code}.yaml', 'w', encoding='utf8') as outfile:
            yaml.dump(translations_file_content, outfile, allow_unicode=True)
