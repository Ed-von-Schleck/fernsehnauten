#!/usr/bin/python
# -*- coding: utf-8 -*-
import subprocess
import cStringIO as StringIO
from pprint import pprint
import datetime
import time
import argparse
import tempfile

from pymongo import Connection
from bson.objectid import ObjectId

from vendor import xmltv

REMOTE_URL = None # address as string if deployed 
CHANNELS = {
    "daserste.de": {
        "position": 1,
        "logo": "daserste.de.svg",
        "tags": ["Hauptsender", "Öffentlich-rechtlich"],
    },
    "zdf.de": {
        "position": 2,
        "logo": "zdf.de.svg",
        "tags": ["Hauptsender", "Öffentlich-rechtlich"],
    },
    "rtl.de": 3, #?
    "prosieben.de": 4, #?
    "sat1.de": 5, #?
    "rtl2.de": 6, #?
    "kabeleins.de": 7, #?
    "vox.de": 8, #?
    "tele5.de": {
        "position": 9,
        "logo": "tele5.de.svg",
        "tags": ["Hauptsender", "Privatsender"],
    }, 
    "arte.de": {
        "position": 10,
        "logo": "arte.de.svg",
        "tags": ["Hauptsender", "Öffentlich-rechtlich"],
    },
    "3sat.de": {
        "position": 11,
        "logo": "3sat.de.svg",
        "tags": ["Hauptsender", "Öffentlich-rechtlich"],
    },
    "superrtl": 12, #?
    "servustv": 13, #?
    "dasvierte": 14, #?
    "comedycentral.de": {
        "position": 15,
        "logo": "comedycentral.de.svg",
        "tags": ["Comedy", "Kids"],
    },
    "bw.swr.de": {
        "position": 20,
        "logo": "bw.swr.de.svg",
        "tags": ["Regionalsender", "Öffentlich-rechtlich"],
    },
    "sr.swr.de": {
        "position": 21,
        "logo": "sr.swr.de.svg",
        "tags": ["Regionalsender", "Öffentlich-rechtlich"],
    },
    "rp.swr.de": {
        "position": 22,
        "logo": "rp.swr.de.svg",
        "tags": ["Regionalsender", "Öffentlich-rechtlich"],
     },
}

def get_timestamp(dt):
    date = datetime.datetime(int(dt[0:4]), int(dt[4:6]), int(dt[6:8]), int(dt[8:10]), int(dt[10:12]), int(dt[12:14]))
    return time.mktime(date.timetuple())

parser = argparse.ArgumentParser(description="Update channel and program data in fernsehnauten's mongodb database.")
parser.add_argument("-r", "--remote", action="store_true", default=False)
args = parser.parse_args()
mongo_url_command = ["meteor", "mongo", "-U"]
if args.remote:
    mongo_url_command.append("fernsehnauten.meteor.com")
if REMOTE_URL is not None:
    mongo_url_command.append(REMOTE_URL)

mongo_url = "mongodb://127.0.0.1:3002/meteor"

print "using mongodb at:", mongo_url
if args.remote:
    db = Connection(mongo_url).fernsehnauten_meteor_com
else:
    db = Connection(mongo_url).meteor

xmltv_file = StringIO.StringIO()
print "downloading data ..."
#xmltv_str = subprocess.check_output(xmltv_command)
xmltv_file = tempfile.NamedTemporaryFile()
xmltv_command = ["xmltv.exe", "tv_grab_eu_egon", "--output", xmltv_file.name]
xmltv_process = subprocess.Popen(xmltv_command)
xmltv_process.wait()
#xmltv_str, err = xmltv_tempfile.read()
print "... done"
#xmltv_file = StringIO.StringIO(xmltv_str)

print "inserting channels ..."
for channel in xmltv.read_channels(xmltv_file):
    channel["_id"] = channel["id"]
    del channel["id"]
    if not channel["_id"] in CHANNELS:
        continue
    channel["position"] = CHANNELS[channel["_id"]]["position"]
    channel["logo"] = CHANNELS[channel["_id"]]["logo"]
    channel["tags"] = CHANNELS[channel["_id"]]["tags"]
    db.channels.save(channel)
print "... done"
xmltv_file.seek(0)
print "inserting programs ..."
for program in xmltv.read_programmes(xmltv_file):
    if not program["channel"] in CHANNELS:
        continue
    program["start"] = get_timestamp(program["start"])
    program["stop"] = get_timestamp(program["stop"])
    program["_id"] = program["channel"] + str(program["start"])
    db.programs.save(program)
print "... done"
