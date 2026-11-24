from odoo.tests import TransactionCase, tagged

from ..controllers.expense import (
    DEFAULT_ICON,
    EXPENSE_ICONS,
    _category_icon,
)


@tagged("-at_install", "post_install")
class TestExpenseCategoryIcons(TransactionCase):
    """`icon` slug for expense categories, tested directly on the name classifier.
    The slug is a stable API value; the client owns the glyph."""

    def assert_icon(self, expected, *names):
        for name in names:
            self.assertEqual(
                _category_icon(name), expected,
                "%r should classify as %r, got %r"
                % (name, expected, _category_icon(name)))

    def test_odoo_shipped_categories(self):
        """`addons/hr_expense/data/hr_expense_data.xml` ships exactly these
        six. Three of them used to fall through to the default."""
        self.assert_icon("utensils", "Meals")
        self.assert_icon("plane", "Travel & Accommodation")
        self.assert_icon("car", "Mileage")
        self.assert_icon("gift", "Gifts")
        self.assert_icon("phone", "Communication")
        self.assert_icon(DEFAULT_ICON, "Expenses")

    def test_mileage_is_driving_not_flying(self):
        """Mileage means your own vehicle, so it maps to car, not plane."""
        self.assert_icon("car", "Mileage", "Mileage Allowance", "mileage")

    def test_keywords_do_not_match_inside_longer_words(self):
        """Keyword matching is word-boundary, not substring."""
        self.assert_icon("wifi", "Cable Internet")
        self.assert_icon("utensils", "Business Meals")
        self.assert_icon("education", "Training Course")
        self.assert_icon("plane", "Flight Booking")       # `book` must not win
        self.assert_icon("car", "Car Rental")             # `rent` must not win
        self.assert_icon(DEFAULT_ICON, "Credit Card Fee")  # `car` must not win

    def test_specific_transport_beats_generic_car(self):
        self.assert_icon("fuel", "Fuel", "Petrol", "Diesel", "Gas Station")
        self.assert_icon("parking", "Parking Fee", "Valet Parking")
        self.assert_icon("toll", "Toll Charges", "Congestion Charge")

    def test_rent_beats_office_supplies(self):
        """`building` precedes `box`: "Office Rent" is rent, not stationery,
        even though it contains "office"."""
        self.assert_icon("building", "Office Rent")
        self.assert_icon("box", "Office Supplies")

    def test_gas_bill_is_a_utility_not_fuel(self):
        """"gas station"/"gasoline" are fuel; a bare gas bill is not."""
        self.assert_icon("building", "Gas Bill")
        self.assert_icon("fuel", "Gas Station")

    def test_every_slug_is_reachable(self):
        """A slug no name can produce is dead weight in the contract."""
        samples = {
            "fuel": "Fuel", "parking": "Parking", "toll": "Toll",
            "plane": "Flight", "train": "Train Ticket", "bus": "Bus Pass",
            "car": "Taxi", "hotel": "Hotel", "passport": "Visa Fee",
            "coffee": "Coffee", "utensils": "Lunch",
            "entertainment": "Team Building", "gift": "Gift Voucher",
            "health": "Pharmacy", "education": "Conference",
            "software": "SaaS Subscription", "laptop": "Laptop",
            "phone": "Mobile Phone", "wifi": "Broadband",
            "printer": "Toner Cartridge", "postage": "Courier",
            "building": "Rent", "box": "Stationery",
            "marketing": "Advertising", "legal": "Legal Fees",
            "bank": "Bank Charge", "insurance": "Insurance Premium",
            "tax": "VAT", "membership": "Gym Membership",
            "receipt": "Something Unclassifiable",
        }
        self.assertEqual(
            set(samples), set(EXPENSE_ICONS),
            "the sample table and EXPENSE_ICONS have drifted -- add a "
            "sample for any new slug")
        for slug, name in samples.items():
            self.assert_icon(slug, name)

    def test_matching_is_case_insensitive(self):
        self.assert_icon("utensils", "LUNCH", "lunch", "Lunch")

    def test_unknown_and_empty_names_fall_back_to_the_default(self):
        """Purely presentational -- it never affects amounts, approval or
        accounting, so degrading to `receipt` is correct, not an error."""
        self.assert_icon(DEFAULT_ICON, "Zzz Unclassifiable", "", None, "   ")

    def test_default_is_part_of_the_vocabulary(self):
        self.assertIn(DEFAULT_ICON, EXPENSE_ICONS)
        self.assertEqual(len(set(EXPENSE_ICONS)), len(EXPENSE_ICONS),
                         "slugs must be unique")
