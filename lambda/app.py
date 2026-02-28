import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

WORLD_MAP = {
    "en": "world",
    "es": "mundo",
    "fr": "monde",
    "de": "welt",
}


def handler(event, context):
    name = event.get("name", "world")
    greeting = event.get("greeting", "hello")
    language = event.get("language", "en")
    title = event.get("title")
    emoji = event.get("emoji", False)

    world = WORLD_MAP.get(language, "world")
    display_name = f"{title} {name}" if title else name
    message = f"{greeting} {world}, {display_name}"
    if emoji:
        message += " \U0001f389"

    log_payload = {
        "message": message,
        "name": name,
        "greeting": greeting,
        "language": language,
        "title": title,
        "emoji": emoji,
    }
    logger.info(json.dumps(log_payload))
    return {"statusCode": 200, "body": json.dumps({"message": message})}
