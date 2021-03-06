import 'dart:collection';

import "package:collection/collection.dart";
import 'package:html/dom.dart';
import 'package:mikan_flutter/internal/caches.dart';
import 'package:mikan_flutter/internal/consts.dart';
import 'package:mikan_flutter/internal/enums.dart';
import 'package:mikan_flutter/internal/extension.dart';
import 'package:mikan_flutter/model/bangumi.dart';
import 'package:mikan_flutter/model/bangumi_details.dart';
import 'package:mikan_flutter/model/bangumi_row.dart';
import 'package:mikan_flutter/model/carousel.dart';
import 'package:mikan_flutter/model/index.dart';
import 'package:mikan_flutter/model/record_details.dart';
import 'package:mikan_flutter/model/record_item.dart';
import 'package:mikan_flutter/model/search.dart';
import 'package:mikan_flutter/model/season.dart';
import 'package:mikan_flutter/model/subgroup.dart';
import 'package:mikan_flutter/model/subgroup_bangumi.dart';
import 'package:mikan_flutter/model/subgroup_gallery.dart';
import 'package:mikan_flutter/model/user.dart';
import 'package:mikan_flutter/model/year_season.dart';

class Resolver {
  static Future<List<BangumiRow>> parseSeason(final Document document) async {
    final List<Element> rowElements =
        document.querySelectorAll("div.sk-bangumi") ?? [];
    final List<BangumiRow> list = [];
    BangumiRow bangumiRow;
    Bangumi bangumi;
    List<Bangumi> bangumis;
    List<Element> bangumiElements;
    Map<dynamic, String> attributes;
    String temp;
    int i = 1;
    for (final Element rowEle in rowElements) {
      bangumiRow = BangumiRow();
      temp = rowEle.children[0].text.trim();
      bangumiRow.name = temp;
      temp = WeekSection.getByName(temp)?.name ?? temp;
      bangumiRow.sname = temp;
      bangumiElements = rowEle.querySelectorAll("li") ?? [];
      bangumis = [];
      for (final Element ele in bangumiElements) {
        bangumi = Bangumi();
        attributes = ele.querySelector("span").attributes;
        bangumi.id = attributes["data-bangumiid"];
        bangumi.cover =
            MikanUrl.BASE_URL + attributes["data-src"].split("?")[0];
        bangumi.grey = ele.querySelector("span.greyout") != null;
        bangumi.updateAt = ele.querySelector(".date-text").text.trim();
        attributes = (ele.querySelector(".an-text") ??
                ele.querySelector(".date-text[title]"))
            .attributes;
        bangumi.name = attributes['title'];
        bangumi.subscribed = ele.querySelector(".active") != null;
        bangumi.num =
            int.tryParse(ele.querySelector(".num-node")?.text ?? "0") ?? 0;
        bangumis.add(bangumi);
        bangumi.week = temp;
        bangumi.location = Location(i, (i / 3).ceil());
        i++;
      }
      bangumiRow.num = bangumis.length;
      bangumiRow.updatedNum =
          bangumis.where((element) => element.num > 0).length;
      bangumiRow.subscribedNum =
          bangumis.where((element) => element.subscribed).length;
      bangumiRow.subscribedUpdatedNum = bangumis
          .where((element) => element.subscribed && element.num > 0)
          .length;
      bangumis.sort((a, b) {
        if (a.subscribed && b.subscribed) {
          return 0;
        } else if (a.subscribed) {
          return -1;
        } else {
          return 1;
        }
      });
      bangumiRow.bangumis = bangumis;
      list.add(bangumiRow);
    }
    return list;
  }

  static Future<List<RecordItem>> parseDay(final Document document) async {
    final List<Element> elements =
        document.querySelectorAll("#an-list-res .my-rss-item") ?? [];
    RecordItem record;
    final List<RecordItem> list = [];
    Element element;
    List<Element> tempEles;
    String temp;
    String tempLowerCase;
    Set<String> tags;
    for (final ele in elements) {
      record = RecordItem();
      element = ele.querySelector("div.sk-col.rss-thumb");
      if (element != null) {
        temp = element.attributes['style'];
        record.cover =
            MikanUrl.BASE_URL + RegExp(r"\((.*)\)").firstMatch(temp).group(1);
      }
      element = ele.querySelector("div.sk-col.rss-name > div > a");
      if (element != null) {
        record.name = element.text.trim();
        temp = element.attributes['href'];
        if (temp.isNotBlank) {
          record.id = temp.substring(14).split("#")[0];
        }
      }
      tempEles = ele.querySelectorAll("div.sk-col.rss-name > a");
      if (tempEles.isNotEmpty) {
        element = tempEles.getOrNull(0);
        if (element != null) {
          temp = element.attributes['href'];
          if (temp.isNotBlank) {
            record.torrent = MikanUrl.BASE_URL + temp;
          }
          temp = element.querySelector("span")?.text?.trim();
          if (temp.isNotBlank) {
            record.size = temp.replaceAll(r"[", "").replaceAll(r"]", "");
          }
          element.querySelector("span")?.remove();
          temp = element.text;
          if (temp.isNotBlank) {
            temp = temp.trim().replaceAll("【", "[").replaceAll("】", "]");
            tempLowerCase = temp.toLowerCase();
            tags = LinkedHashSet();
            keywords.forEach((key, value) {
              if (tempLowerCase.contains(key)) {
                tags.add(value);
              }
            });
            record.title = temp;
            record.tags = tags.toList()..sort((a, b) => a.compareTo(b));
          }
        }
        element = tempEles.getOrNull(1);
        record.magnet = element?.attributes?.getOrNull('data-clipboard-text');
        element = tempEles.getOrNull(2);
        record.url = element?.attributes?.getOrNull("href");
      }
      record.publishAt =
          ele.querySelector("div.sk-col.pull-right")?.text?.trim();
      list.add(record);
    }
    return list;
  }

  static Future<User> parseUser(final Document document) async {
    final String name =
        document.querySelector("#user-name .text-right")?.text?.trim();
    final String avatar = document
        ?.querySelector("#user-welcome #head-pic")
        ?.attributes
        ?.getOrNull("src");
    final String token = document
        .querySelector("#login input[name=__RequestVerificationToken]")
        ?.attributes
        ?.getOrNull("value");
    return User(
      name: name,
      avatar: avatar == null ? null : MikanUrl.BASE_URL + avatar,
      token: token,
    );
  }

  static Future<SearchResult> parseSearch(final Document document) async {
    List<Element> eles = document.querySelectorAll(
            "div.leftbar-container .leftbar-item .subgroup-longname") ??
        [];
    final List<Subgroup> subgroups = [];
    String temp;
    Subgroup subgroup;
    for (final Element ele in eles) {
      temp = ele.attributes['data-subgroupid'];
      if (temp.isNotBlank) {
        subgroup = Subgroup();
        subgroup.id = temp;
        subgroup.name = ele.text.trim();
        subgroups.add(subgroup);
      }
    }
    eles = document.querySelectorAll("div.central-container > ul > li") ?? [];
    final List<Bangumi> bangumis = [];
    Bangumi bangumi;
    for (final Element ele in eles) {
      bangumi = Bangumi();
      temp = ele
          .querySelector("a")
          .attributes['href'];
      bangumi.id = temp.replaceAll("/Home/Bangumi/", "");
      bangumi.cover = MikanUrl.BASE_URL +
          ele
              .querySelector("span")
              .attributes["data-src"].split("?")[0];
      bangumi.name = ele
          .querySelector(".an-text")
          .attributes['title'].trim();
      bangumis.add(bangumi);
    }
    eles = document.querySelectorAll("tr.js-search-results-row") ?? [];
    RecordItem record;
    List<RecordItem> searchs = [];
    List<Element> elements;
    String tempLowerCase;
    Set<String> tags;
    for (final Element ele in eles) {
      record = RecordItem();
      elements = ele.querySelectorAll("td");
      record.url =
          MikanUrl.BASE_URL + elements[0].children[0].attributes['href'];
      temp = elements
          .getOrNull(0)
          ?.children
          ?.getOrNull(0)
          ?.text;
      if (temp.isNotBlank) {
        temp = temp.trim().replaceAll("【", "[").replaceAll("】", "]");
        tags = LinkedHashSet();
        tempLowerCase = temp.toLowerCase();
        keywords.forEach((key, value) {
          if (tempLowerCase.contains(key)) {
            tags.add(value);
          }
        });
        record.tags = tags.toList()
          ..sort((a, b) => a.compareTo(b));
        record.title = temp;
      }
      record.size = elements[1].text.trim();
      record.publishAt = elements[2].text.trim();
      record.magnet = elements[0].children[1].attributes["data-clipboard-text"];
      record.torrent =
          MikanUrl.BASE_URL + elements[3].children[0].attributes["href"];
      searchs.add(record);
    }
    return SearchResult(
      bangumis: bangumis,
      subgroups: subgroups,
      searchs: searchs,
    );
  }

  static Future<List<RecordItem>> parseList(final Document document) async {
    final List<Element> eles =
        document.querySelectorAll("#sk-body > table > tbody > tr") ?? [];
    final List<RecordItem> records = [];
    RecordItem record;
    Subgroup subgroup;
    List<Subgroup> subgroups;
    Element element;
    Element tempElement;
    List<Element> elements;
    List<Element> tempElements;
    String temp;
    String tempLowerCase;
    Set<String> tags;
    for (final Element ele in eles) {
      elements = ele.children ?? [];
      record = RecordItem();
      record.publishAt = elements[0].text.trim();
      element = elements[1];
      tempElements = element.querySelectorAll("li");
      subgroups = [];
      if (tempElements != null && tempElements.length > 0) {
        for (Element ele in tempElements) {
          tempElement = ele.children[0];
          subgroup = Subgroup();
          temp = tempElement.attributes['href'];
          subgroup.id = temp.substring(19);
          subgroup.name = tempElement.text.trim();
          subgroups.add(subgroup);
        }
      } else if (element.children.length > 0) {
        tempElement = element.children[0];
        subgroup = Subgroup();
        temp = tempElement.attributes['href'];
        subgroup.id = temp.substring(19);
        subgroup.name = tempElement.text.trim();
        subgroups.add(subgroup);
      } else {
        subgroup = Subgroup();
        subgroup.name = element.text.trim();
        subgroups.add(subgroup);
      }
      record.groups = subgroups;
      tempElements = elements[2].children;
      tempElement = tempElements[0];
      temp = tempElement.text;
      if (temp.isNotBlank) {
        temp = temp.trim().replaceAll("【", "[").replaceAll("】", "]");
        tags = LinkedHashSet();
        tempLowerCase = temp.toLowerCase();
        keywords.forEach((key, value) {
          if (tempLowerCase.contains(key)) {
            tags.add(value);
          }
        });
        record.tags = tags.toList()
          ..sort((a, b) => a.compareTo(b));
        record.title = temp;
      }
      record.url = MikanUrl.BASE_URL + tempElement.attributes['href'];
      record.magnet = tempElements[1].attributes['data-clipboard-text'];
      record.size = elements[3].text.trim();
      record.torrent =
          MikanUrl.BASE_URL + elements[4].children[0].attributes['href'];
      records.add(record);
    }
    return records;
  }

  static Future<Index> parseIndex(final Document document) async {
    final List<BangumiRow> bangumiRows = await parseSeason(document);
    final List<RecordItem> rss = await parseDay(document);
    final List<Carousel> carousels = await parseCarousel(document);
    final List<YearSeason> years = await parseYearSeason(document);
    final User user = await parseUser(document);
    final Map<String, List<RecordItem>> _rss = groupBy(rss, (it) => it.id);
    return Index(
      years: years,
      bangumiRows: bangumiRows,
      rss: _rss,
      carousels: carousels,
      user: user,
    );
  }

  static Future<List<Carousel>> parseCarousel(final Document document) async {
    final List<Element> eles = document.querySelectorAll(
        "#myCarousel > div.carousel-inner > div.item.carousel-bg") ??
        [];
    final List<Carousel> carousels = [];
    Carousel carousel;
    String temp;
    for (final Element ele in eles) {
      carousel = Carousel();
      temp = ele.attributes['style'];
      carousel.cover = MikanUrl.BASE_URL + temp.split("'")[1];
      temp = ele.attributes["onclick"];
      temp = temp.split("'")[1];
      carousel.id = temp.substring(temp.lastIndexOf("/") + 1);
      carousels.add(carousel);
    }
    return carousels;
  }

  static Future<List<YearSeason>> parseYearSeason(
      final Document document) async {
    final List<Element> eles = document.querySelectorAll(
        "#sk-data-nav > div > ul.navbar-nav.date-select > li > ul > li") ??
        [];
    final String selected = document
        .querySelector("#sk-data-nav  .date-select  div.date-text")
        ?.text
        ?.trim();
    List<YearSeason> yearSeasons = [];
    YearSeason yearSeason;
    List<Season> seasons;
    Season season;
    Map attributes;
    for (final Element ele in eles) {
      yearSeason = YearSeason();
      yearSeason.year = ele.children[0].text.trim();
      seasons = [];
      Element element;
      for (final Element e in ele.children[1].children) {
        season = Season();
        element = e.children[0];
        attributes = element.attributes;
        season.year = attributes["data-year"];
        season.season = attributes["data-season"];
        season.title = season.year + ' ' + element.text.trim();
        season.active = season.title == selected;
        seasons.add(season);
      }
      yearSeason.seasons = seasons;
      yearSeasons.add(yearSeason);
    }
    return yearSeasons;
  }

  static Future<List<SubgroupGallery>> parseSubgroup(
      final Document document,) async {
    final List<Element> eles = document.querySelectorAll(
        "#js-sort-wrapper > div.pubgroup-timeline-item[data-index]");
    List<SubgroupGallery> list = [];
    SubgroupGallery subgroupGallery;
    Bangumi bangumi;
    List<Bangumi> bangumis;
    List<Element> elements;
    Map attributes;
    int i = 1;
    for (final Element ele in eles) {
      subgroupGallery = SubgroupGallery();
      subgroupGallery.date = ele
          .querySelector(".pubgroup-date")
          .text
          .trim();
      subgroupGallery.season =
          ele
              .querySelector(".pubgroup-season")
              .text
              .trim();
      subgroupGallery.isCurrentSeason =
          ele.querySelector(".pubgroup-season.current-season") != null;
      elements = ele.querySelectorAll("li[data-bangumiid]") ?? [];
      bangumis = [];
      for (final Element e in elements) {
        bangumi = Bangumi();
        bangumi.id = e.attributes['data-bangumiid'];
        attributes = e
            .querySelector("div.an-info-group > a")
            .attributes;
        bangumi.name = attributes['title'];
        bangumi.subscribed = e.querySelector(".an-info-icon.active") != null;
        bangumi.cover = MikanUrl.BASE_URL +
            e
                .querySelector("span[data-bangumiid]")
                ?.attributes
                ?.getOrNull('data-src')
                ?.split("?")
                ?.elementAt(0) ??
            "";
        bangumi.location = Location(i, (i / 3).ceil());
        i++;
        bangumis.add(bangumi);
      }
      bangumis.sort((a, b) {
        if (a.subscribed && b.subscribed) {
          return 0;
        } else if (a.subscribed) {
          return -1;
        } else {
          return 1;
        }
      });
      subgroupGallery.bangumis = bangumis;
      list.add(subgroupGallery);
    }
    return list;
  }

  static Future<BangumiDetails> parseBangumi(final Document document) async {
    final BangumiDetails bangumiDetails = BangumiDetails();
    bangumiDetails.id = document
        .querySelector(
        "#sk-container > div.pull-left.leftbar-container > p.bangumi-title > a")
        ?.attributes
        ?.getOrNull("href")
        ?.split("=")
        ?.getOrNull(1);
    bangumiDetails.cover = MikanUrl.BASE_URL +
        document
            .querySelector(
            "#sk-container > div.pull-left.leftbar-container > div.bangumi-poster")
            ?.attributes
            ?.getOrNull("style")
            ?.split("'")
            ?.elementAt(1)
            ?.split("?")
            ?.elementAt(0) ??
        '';
    bangumiDetails.name = document
        .querySelector(
        "#sk-container > div.pull-left.leftbar-container > p.bangumi-title")
        ?.text
        ?.trim();
    String _intro = document
        .querySelector("#sk-container > div.central-container > p")
        ?.text
        ?.trim();
    if (_intro.isNotBlank) {
      _intro = "\u3000\u3000" + _intro.replaceAll("\n", "\n\u3000\u3000");
    }
    bangumiDetails.intro = _intro;
    bangumiDetails.subscribed = document
        .querySelector(".subscribed-badge")
        ?.attributes
        ?.getOrNull("style")
        ?.isNullOrBlank ??
        false;
    final more = document
        .querySelectorAll(
        "#sk-container > div.pull-left.leftbar-container > p.bangumi-info")
        ?.map((e) => e.text.split("：")) ??
        [];
    final Map<String, String> map = {};
    more.forEach((element) {
      map[element[0].trim()] = element[1].trim();
    });
    bangumiDetails.more = map;
    final List<Element> tables = document
        .querySelectorAll("#sk-container > div.central-container > table");
    final List<Element> subs = document.querySelectorAll(".subgroup-text");
    bangumiDetails.subgroupBangumis = [];
    SubgroupBangumi subgroupBangumi;
    Element element;
    List<Element> elements;
    String temp;
    List<RecordItem> records;
    RecordItem record;
    String tempLowerCase;
    Set<String> tags;
    List<Subgroup> subgroups;
    Subgroup subgroup;
    if (tables.length == subs.length) {
      for (int i = 0; i < tables.length; i++) {
        subgroupBangumi = SubgroupBangumi();
        element = subs.elementAt(i);
        temp = element.children[0].attributes["href"];
        subgroupBangumi.subgroupId = element.attributes?.getOrNull("id");
        temp = element.nodes
            .getOrNull(0)
            ?.text
            ?.trim();
        if (temp.isNullOrBlank) {
          final Element child =
              element.querySelector(".dropdown span") ?? element.children[0];
          subgroupBangumi.name = child?.text?.trim();
        } else {
          subgroupBangumi.name = temp;
        }
        subgroupBangumi.subscribed =
            element
                ?.querySelector(".subscribed")
                ?.text
                ?.trim() == "已订阅";
        subgroups = [];
        elements = element.querySelectorAll("ul > li > a");
        if (elements.isSafeNotEmpty) {
          for (final Element ele in elements) {
            subgroup = Subgroup();
            subgroup.name = ele.text;
            subgroup.id = ele.attributes["href"]
                .split("/")
                .last;
            subgroups.add(subgroup);
          }
        } else {
          subgroups.add(Subgroup(
            id: subgroupBangumi.subgroupId,
            name: subgroupBangumi.name,
          ));
        }
        records = [];
        element = tables.elementAt(i);
        elements = element.querySelectorAll("tbody > tr");
        for (final Element ele in elements) {
          record = RecordItem();
          element = ele.children[0];
          record.magnet = element.children[1].attributes['data-clipboard-text'];
          element = element.children[0];
          temp = element.text;
          if (temp.isNotBlank) {
            temp = temp.trim().replaceAll("【", "[").replaceAll("】", "]");
            tempLowerCase = temp.toLowerCase();
            tags = LinkedHashSet();
            keywords.forEach((key, value) {
              if (tempLowerCase.contains(key)) {
                tags.add(value);
              }
            });
            record.title = temp;
            record.tags = tags.toList()
              ..sort((a, b) => a.compareTo(b));
          }
          record.url = MikanUrl.BASE_URL + element.attributes["href"];
          record.size = ele.children[1].text.trim();
          record.publishAt = ele.children[2].text.trim();
          record.torrent = MikanUrl.BASE_URL +
              ele.children[3].children[0].attributes["href"];
          records.add(record);
        }
        subgroupBangumi.subgroups = subgroups;
        subgroupBangumi.records = records;
        bangumiDetails.subgroupBangumis.add(subgroupBangumi);
      }
    }
    return bangumiDetails;
  }

  static Future<RecordDetails> parseDetails(final Document document) async {
    final RecordDetails recordDetails = RecordDetails();
    recordDetails.id = document
        .querySelector(
        "#sk-container > div.pull-left.leftbar-container > div.leftbar-nav > button")
        ?.attributes
        ?.getOrNull("data-bangumiid");
    recordDetails.cover = MikanUrl.BASE_URL +
        document
            .querySelector(
            "#sk-container > div.pull-left.leftbar-container > div.bangumi-poster")
            ?.attributes
            ?.getOrNull("style")
            ?.split("'")
            ?.elementAt(1)
            ?.split("?")
            ?.elementAt(0) ??
        '';
    recordDetails.name = document
        .querySelector(
        "#sk-container > div.pull-left.leftbar-container > p.bangumi-title")
        ?.text
        ?.trim();
    String title = document
        .querySelector(
        "#sk-container > div.central-container > div.episode-header > p")
        ?.text
        ?.trim();
    final Set<String> tags = LinkedHashSet();
    if (title.isNotBlank) {
      title = title.replaceAll("【", "[").replaceAll("】", "]");
      recordDetails.title = title;
      final String lowerCaseTitle = title.toLowerCase();
      keywords.forEach((key, value) {
        if (lowerCaseTitle.contains(key)) {
          tags.add(value);
        }
      });
      recordDetails.tags = tags.toList()
        ..sort((a, b) => a.compareTo(b));
    }
    recordDetails.subscribed = document
        .querySelector(".subscribed-badge")
        ?.attributes
        ?.getOrNull("style")
        ?.isNullOrBlank ??
        false;
    final more = document
        .querySelectorAll(
        "#sk-container > div.pull-left.leftbar-container > p.bangumi-info")
        ?.map((e) => e.text.split("：")) ??
        [];
    final Map<String, String> map = {};
    more.forEach((element) {
      map[element[0].trim()] = element[1].trim();
    });
    recordDetails.more = map;
    String temp;
    List<Element> elements = document.querySelectorAll(
        "#sk-container > div.pull-left.leftbar-container > div.leftbar-nav > a");
    elements.forEach((element) {
      temp = element.text;
      if (temp == "下载种子") {
        recordDetails.torrent = MikanUrl.BASE_URL + element.attributes["href"];
      } else if (temp == "磁力链接") {
        recordDetails.magnet = element.attributes['href'];
      }
    });
    final Element element = document.querySelector(
        "#sk-container > div.central-container > div.episode-desc");
    element.children.forEach((ele) {
      if (ele.attributes['style'].isNotBlank) {
        ele.remove();
      }
    });
    recordDetails.intro = element.innerHtml.trim();
    return recordDetails;
  }

  static Future<List<RecordItem>> parseBangumiMore(Document document) async {
    final elements = document.querySelectorAll("tbody > tr");
    RecordItem record;
    Element element;
    List<RecordItem> records = [];
    String tempLowerCase;
    Set<String> tags;
    String temp;
    for (final Element ele in elements) {
      record = RecordItem();
      element = ele.children[0];
      record.magnet = element.children[1].attributes['data-clipboard-text'];
      element = element.children[0];
      temp = element.text;
      if (temp.isNotBlank) {
        temp = temp.trim().replaceAll("【", "[").replaceAll("】", "]");
        tempLowerCase = temp.toLowerCase();
        tags = LinkedHashSet();
        keywords.forEach((key, value) {
          if (tempLowerCase.contains(key)) {
            tags.add(value);
          }
        });
        record.title = temp;
        record.tags = tags.toList()
          ..sort((a, b) => a.compareTo(b));
      }
      record.url = MikanUrl.BASE_URL + element.attributes["href"];
      record.size = ele.children[1].text.trim();
      record.publishAt = ele.children[2].text.trim();
      record.torrent =
          MikanUrl.BASE_URL + ele.children[3].children[0].attributes["href"];
      records.add(record);
    }
    return records;
  }
}
