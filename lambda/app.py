import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    name = event.get("name", "world")
    message = f"hello world, {name}"
    logger.info(json.dumps({"message": message, "name": name}))
    return {"statusCode": 200, "body": json.dumps({"message": message})}
