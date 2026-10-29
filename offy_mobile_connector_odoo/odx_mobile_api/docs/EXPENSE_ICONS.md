# Expense category icons

> **Generated file — do not edit.**
> Source: `controllers/expense.py` (`_ICON_KEYWORDS`).
> Regenerate: `python3 tools/generate_expense_icon_reference.py`
> Last generated: 2026-08-11

The `icon` field returned by:

```
GET /api/mobile/v1/expense          -> data.expenses[].icon
GET /api/mobile/v1/expense/categories -> data[].icon
```

## What it is

A **stable API slug**, not a Material or FontAwesome icon name. The
server classifies the expense category name (`product_id.name`); the
client owns the glyph. Adding a slug is a contract *addition* — a
client that does not recognise one must fall back to `receipt`
rather than break.

Purely presentational. It never affects amounts, approval or
accounting, so an unrecognised category name resolving to `receipt`
is a correct outcome, not an error.

## Matching rules

1. **Whole word, case-insensitive.** The name is matched against
   `\b(?:keyword|…)\b`, never as a bare substring. This is what makes
   short keywords safe: `car` does not match *card*, `tax` does not
   match *taxi*, `bus` does not match *business*, `book` does not
   match *booking*.
2. **First match wins.** The table order below is significant and is
   part of the contract — see the ordering notes at the end.
3. **No match → `receipt`.**

## The 30 slugs, in evaluation order

| # | `icon` | Matches when the category name contains |
|---|---|---|
| 1 | `fuel` | fuel, petrol, diesel, gasoline, gas station, ev charging, charging |
| 2 | `parking` | parking, valet |
| 3 | `toll` | toll, tolls, congestion charge |
| 4 | `plane` | flight, flights, airfare, airline, air ticket, air travel, travel, trip, tour, baggage |
| 5 | `train` | train, rail, railway, metro, subway, tram |
| 6 | `bus` | bus, shuttle |
| 7 | `car` | taxi, cab, uber, lyft, ride, rideshare, car, vehicle, mileage, transport, commute, driving |
| 8 | `hotel` | hotel, accommodation, lodging, motel, hostel, airbnb, stay |
| 9 | `passport` | visa, passport, immigration, work permit |
| 10 | `coffee` | coffee, cafe, tea, snack, snacks, beverage, beverages, refreshment, refreshments |
| 11 | `utensils` | meal, meals, food, lunch, dinner, breakfast, restaurant, catering, per diem, groceries |
| 12 | `entertainment` | entertainment, event, events, team building, hospitality, social event |
| 13 | `gift` | gift, gifts, present, award, reward, incentive |
| 14 | `health` | medical, health, healthcare, doctor, pharmacy, hospital, clinic, dental, medicine |
| 15 | `education` | training, course, courses, seminar, conference, workshop, certification, tuition, exam, book, books, education, learning |
| 16 | `software` | software, saas, license, licence, subscription, cloud, hosting, domain |
| 17 | `laptop` | laptop, computer, hardware, equipment, monitor, device, peripheral |
| 18 | `phone` | phone, mobile, telephone, sim, airtime, roaming, communication |
| 19 | `wifi` | internet, wifi, broadband, data plan |
| 20 | `printer` | printing, print, photocopy, copier, toner, cartridge |
| 21 | `postage` | postage, courier, shipping, freight, delivery, parcel, mail |
| 22 | `building` | rent, lease, utilities, electricity, water, gas bill, facility, cleaning, maintenance |
| 23 | `box` | supplies, stationery, consumable, consumables, office |
| 24 | `marketing` | marketing, advertising, advert, adverts, promotion, campaign, sponsorship, branding, media |
| 25 | `legal` | legal, lawyer, attorney, notary, compliance, audit, consulting, professional fee |
| 26 | `bank` | bank, bank fee, bank charge, transaction fee, forex, exchange rate, interest |
| 27 | `insurance` | insurance, premium, policy |
| 28 | `tax` | tax, taxes, vat, gst, duty, customs, levy |
| 29 | `membership` | membership, association, dues, union dues, club |
| 30 | `receipt` | *(default — nothing above matched)* |

## Ordering rules that are load-bearing

If you reorder the table, preserve these:

- `fuel` / `parking` / `toll` **before** `car` — otherwise a fuel or
  parking claim is swallowed by the generic vehicle bucket.
- `plane` **before** `car` — a bare "Travel" category has mapped to
  `plane` since the first version; keep it there.
- `building` **before** `box` — "Office Rent" is rent, not office
  supplies, even though it contains *office*.
- `car` **before** `building` — "Car Rental" is a vehicle. Whole-word
  matching already stops `rent` matching *rental*, so this is
  belt-and-braces.

## Odoo's shipped categories

`addons/hr_expense/data/hr_expense_data.xml` ships exactly six, which
every database starts with:

| Category | `icon` |
|---|---|
| Meals | `utensils` |
| Travel & Accommodation | `plane` |
| Mileage | `car` |
| Gifts | `gift` |
| Communication | `phone` |
| Expenses | `receipt` |

## Known limitation

The keyword table is **English-only**. A database whose expense
categories are named in another language classifies everything as
`receipt`. Fixing that properly means keying off something
language-independent (a category field, or an `ir.model.data` xmlid)
rather than translating the table.

## For client implementers

`EXPENSE_ICONS` in `controllers/expense.py` exports every slug in
order, so a client-side mapping can be generated from it rather than
hand-copied. Always include a `default:` branch.

Dart sketch:

```dart
IconData iconFor(String slug) {
  switch (slug) {
    case 'fuel':
      return /* your glyph */;
    case 'parking':
      return /* your glyph */;
    case 'toll':
      return /* your glyph */;
    case 'plane':
      return /* your glyph */;
    case 'train':
      return /* your glyph */;
    case 'bus':
      return /* your glyph */;
    case 'car':
      return /* your glyph */;
    case 'hotel':
      return /* your glyph */;
    case 'passport':
      return /* your glyph */;
    case 'coffee':
      return /* your glyph */;
    case 'utensils':
      return /* your glyph */;
    case 'entertainment':
      return /* your glyph */;
    case 'gift':
      return /* your glyph */;
    case 'health':
      return /* your glyph */;
    case 'education':
      return /* your glyph */;
    case 'software':
      return /* your glyph */;
    case 'laptop':
      return /* your glyph */;
    case 'phone':
      return /* your glyph */;
    case 'wifi':
      return /* your glyph */;
    case 'printer':
      return /* your glyph */;
    case 'postage':
      return /* your glyph */;
    case 'building':
      return /* your glyph */;
    case 'box':
      return /* your glyph */;
    case 'marketing':
      return /* your glyph */;
    case 'legal':
      return /* your glyph */;
    case 'bank':
      return /* your glyph */;
    case 'insurance':
      return /* your glyph */;
    case 'tax':
      return /* your glyph */;
    case 'membership':
      return /* your glyph */;
    default: // includes 'receipt' and any slug added later
      return Icons.receipt_long;
  }
}
```
