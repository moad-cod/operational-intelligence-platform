from datetime import datetime

from pydantic import BaseModel


class User(BaseModel):
    id: int
    username: str
    email: str
    role: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class UserPublic(BaseModel):
    username: str
    email: str
    role: str
    created_at: datetime


class UserInDB(User):
    hashed_password: str
