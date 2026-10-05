import json
import os
import uuid
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

TABLE_NAME = os.environ["TABLE_NAME"]
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
    "Content-Type": "application/json",
}


def _response(status, body=None):
    return {
        "statusCode": status,
        "headers": CORS_HEADERS,
        "body": "" if body is None else json.dumps(body, default=str),
    }


def _now():
    return datetime.now(timezone.utc).isoformat()


def list_tasks():
    items = table.scan().get("Items", [])
    items.sort(key=lambda t: t.get("createdAt", ""), reverse=True)
    return _response(200, items)


def get_task(task_id):
    item = table.get_item(Key={"id": task_id}, ConsistentRead=True).get("Item")
    if not item:
        return _response(404, {"error": "not found"})
    return _response(200, item)


def create_task(payload):
    title = (payload.get("title") or "").strip()
    if not title:
        return _response(400, {"error": "title is required"})
    now = _now()
    item = {
        "id": str(uuid.uuid4()),
        "title": title,
        "completed": bool(payload.get("completed", False)),
        "createdAt": now,
        "updatedAt": now,
    }
    table.put_item(Item=item)
    return _response(201, item)


def update_task(task_id, payload):
    existing = table.get_item(Key={"id": task_id}, ConsistentRead=True).get("Item")
    if not existing:
        return _response(404, {"error": "not found"})

    updates = {}
    if "title" in payload:
        title = (payload.get("title") or "").strip()
        if not title:
            return _response(400, {"error": "title cannot be empty"})
        updates["title"] = title
    if "completed" in payload:
        updates["completed"] = bool(payload["completed"])

    if not updates:
        return _response(400, {"error": "no fields to update"})

    updates["updatedAt"] = _now()

    expr_names = {f"#{k}": k for k in updates}
    expr_values = {f":{k}": v for k, v in updates.items()}
    set_expr = ", ".join(f"#{k} = :{k}" for k in updates)

    result = table.update_item(
        Key={"id": task_id},
        UpdateExpression=f"SET {set_expr}",
        ExpressionAttributeNames=expr_names,
        ExpressionAttributeValues=expr_values,
        ReturnValues="ALL_NEW",
    )
    return _response(200, result["Attributes"])


def delete_task(task_id):
    existing = table.get_item(Key={"id": task_id}, ConsistentRead=True).get("Item")
    if not existing:
        return _response(404, {"error": "not found"})
    table.delete_item(Key={"id": task_id})
    return _response(204)


def lambda_handler(event, context):
    method = (
        event.get("requestContext", {}).get("http", {}).get("method")
        or event.get("httpMethod")
        or "GET"
    ).upper()

    if method == "OPTIONS":
        return _response(204)

    raw_path = event.get("rawPath") or event.get("path") or "/"
    path_params = event.get("pathParameters") or {}
    task_id = path_params.get("id")

    body = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        import base64

        body = base64.b64decode(body).decode("utf-8")
    try:
        payload = json.loads(body) if body else {}
    except json.JSONDecodeError:
        return _response(400, {"error": "invalid JSON"})

    try:
        if raw_path.rstrip("/") in ("/tasks", "") and not task_id:
            if method == "GET":
                return list_tasks()
            if method == "POST":
                return create_task(payload)
            return _response(405, {"error": "method not allowed"})

        if task_id:
            if method == "GET":
                return get_task(task_id)
            if method == "PUT":
                return update_task(task_id, payload)
            if method == "DELETE":
                return delete_task(task_id)
            return _response(405, {"error": "method not allowed"})

        return _response(404, {"error": "route not found"})
    except ClientError as e:
        return _response(500, {"error": str(e)})
