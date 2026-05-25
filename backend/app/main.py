from fastapi import FastAPI

app = FastAPI(
    title="AI Ticket Intelligence Platform"
)

@app.get("/")
def root():
    return {"message": "AI Ticket Intelligence API Running"}