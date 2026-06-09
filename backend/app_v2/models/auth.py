import re

from pydantic import BaseModel, Field, field_validator


class LoginRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=6)


class RegisterRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    email: str = Field(pattern=r"^[\w\.-]+@[\w\.-]+\.\w+$")
    password: str = Field(min_length=8)

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one digit")
        if not re.search(r"[!@#$%^&*(),.?\":{}|<>_\-+]", v):
            raise ValueError("Password must contain at least one special character")
        return v


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"
    username: str
    role: str


class RefreshRequest(BaseModel):
    refresh_token: str


class RegisterResponse(BaseModel):
    message: str
    username: str
