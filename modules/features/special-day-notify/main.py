#!/usr/bin/env python3
import json
from datetime import date
from lunarcalendar import Lunar
from lunarcalendar.festival import Festival, festivals
from urllib import request, parse

special_days = [
    Festival(
        lambda year: Lunar(year, 5, 8).to_date(),
        zh_hans="胖娃的生日",
    ),
    Festival(
        lambda year: Lunar(year, 6, 27).to_date(),
        zh_hans="悦娃的生日",
    ),
    Festival(
        lambda year: Lunar(year, 5, 7).to_date(),
        zh_hans="杨爸的生日",
    ),
    Festival(
        lambda year: Lunar(year - 1, 12, 18).to_date(),
        zh_hans="杨妈的生日",
    ),
    Festival(
        lambda year: date(year, 4, 16),
        zh_hans="竹竹的生日",
    ),
    Festival(
        lambda year: date(year, 10, 6),
        zh_hans="结婚周年",
    ),
    Festival(
        lambda year: date(year, 2, 14),
        zh_hans="情人节",
    ),
    Festival(
        lambda year: date(year, 5, 20),
        zh_hans="520",
    ),
    Festival(
        lambda year: Lunar(year, 7, 7).to_date(),
        zh_hans="七夕节",
    ),
]


def handle_msg(msg: str):
    print(msg)
    body = {"title": "节日提醒", "body": msg, "tag": "me"}
    req = request.Request(
        "http://localhost:3102",
        json.dumps(body).encode("utf-8"),
        {"content-type": "application/json"},
    )
    request.urlopen(req)


def main():
    today = date.today()
    # today = date(2024, 5, 19)

    for festival in festivals:
        if (festival(today.year) - today).days == 0:
            desc = festival.get_lang("zh")
            handle_msg(f"今天是「{desc}」~")

    for special in special_days:
        days = (special(today.year) - today).days
        desc = special.get_lang("zh")
        if days == 0:
            handle_msg(f"今天是「{desc}」~")
        elif days == 1:
            handle_msg(f"明天是「{desc}」~")
        elif days > 1 and days <= 7:
            handle_msg(f"距离「{desc}」还有 {days} 天~")


main()
