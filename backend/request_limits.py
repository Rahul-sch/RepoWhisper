"""Bound request bodies before JSON parsing or media decoding."""
from starlette.responses import JSONResponse


class RequestLimits:
    LIMITS = {
        "/transcribe": 10 * 1024 * 1024,
        "/transcribe-file": 50 * 1024 * 1024,
        "/screenshot": 20 * 1024 * 1024,
        "/advise": 31 * 1024 * 1024,
    }

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        limit = self.LIMITS.get(scope["path"], 2 * 1024 * 1024)
        lengths = [v for k, v in scope["headers"] if k.lower() == b"content-length"]
        if lengths and (len(lengths) != 1 or not lengths[0].isdigit()):
            return await JSONResponse({"detail": "Invalid Content-Length"}, 400)(scope, receive, send)
        if lengths and (len(lengths[0]) > 10 or int(lengths[0]) > limit):
            return await JSONResponse({"detail": "Request body too large"}, 413)(scope, receive, send)
        body = bytearray()
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            chunk = message.get("body", b"")
            if len(body) + len(chunk) > limit:
                return await JSONResponse({"detail": "Request body too large"}, 413)(scope, receive, send)
            body.extend(chunk)
            if not message.get("more_body", False):
                break
        if lengths and len(body) != int(lengths[0]):
            return await JSONResponse({"detail": "Body length mismatch"}, 400)(scope, receive, send)
        delivered = False

        async def replay():
            nonlocal delivered
            if delivered:
                return await receive()
            delivered = True
            return {"type": "http.request", "body": bytes(body), "more_body": False}

        await self.app(scope, replay, send)
