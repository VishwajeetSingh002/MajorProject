from fastapi import FastAPI
import uvicorn
import os
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()

# Instrument the FastAPI app for Prometheus
Instrumentator().instrument(app).expose(app)

@app.get("/")
def health_check():
    return {"status": "healthy"}

@app.get("/users")
def get_users():
    return [
        {"id": 1, "name": "Alice Smith", "email": "alice@example.com"},
        {"id": 2, "name": "Bob Jones", "email": "bob@example.com"}
    ]

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
