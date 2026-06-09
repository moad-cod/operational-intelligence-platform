import logging

from fastapi import HTTPException, status

from app_v2.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    verify_password,
)
from app_v2.db.user_repository_class import UserRepository

logger = logging.getLogger(__name__)


class AuthService:

    def __init__(self, user_repo: UserRepository) -> None:
        self.user_repo = user_repo

    async def login(
        self,
        username: str,
        plain_password: str,
    ) -> dict:
        user = await self.user_repo.get_user_by_username(username)
        if user is None or not verify_password(plain_password, user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account disabled",
            )
        return {
            "access_token": create_access_token({"sub": user.username}),
            "refresh_token": create_refresh_token({"sub": user.username}),
            "token_type": "bearer",
            "username": user.username,
            "role": user.role,
        }

    async def register(
        self,
        username: str,
        email: str,
        plain_password: str,
    ) -> dict:
        existing = await self.user_repo.get_user_by_username(username)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already taken",
            )
        existing_email = await self.user_repo.get_user_by_email(email)
        if existing_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered",
            )
        user = await self.user_repo.create_user(
            username, email, plain_password,
        )
        return {
            "message": "User created successfully",
            "username": user.username,
        }

    async def refresh(
        self,
        refresh_token: str,
    ) -> dict:
        payload = decode_token(refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type",
                headers={"WWW-Authenticate": "Bearer"},
            )
        user = await self.user_repo.get_user_by_username(
            payload.get("sub", "")
        )
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return {
            "access_token": create_access_token({"sub": user.username}),
            "token_type": "bearer",
        }
