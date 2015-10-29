#!/bin/zsh
#
# Forces AD DC used for Isilon
#
dc=auper-dc01.neptunems.com
domain=neptunems.com
isi_classic auth ads dc --domain=${domain} --set-dc=${dc}
