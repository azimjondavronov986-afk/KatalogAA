import json

DEFAULT_ORDER_FIELDS = [
    "Ism",
    "Telefon",
    "Dona soni",
    "Izoh"
]


def parse_order_fields(value):
    if not value:
        return DEFAULT_ORDER_FIELDS

    try:
        data = json.loads(value)
        if isinstance(data, list) and data:
            return data
    except Exception:
        pass

    return DEFAULT_ORDER_FIELDS


def make_order_fields_text(fields_text):
    if not fields_text:
        return json.dumps(DEFAULT_ORDER_FIELDS, ensure_ascii=False)

    fields = []
    for line in fields_text.replace(",", "\n").splitlines():
        line = line.strip()
        if line:
            fields.append(line)

    if not fields:
        fields = DEFAULT_ORDER_FIELDS

    return json.dumps(fields, ensure_ascii=False)
