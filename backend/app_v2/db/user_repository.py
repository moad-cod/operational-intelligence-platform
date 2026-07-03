from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app_v2.core.security import hash_password
from app_v2.db.user_model import UserDB


async def get_user_by_username(
    username: str,
    db: AsyncSession,
) -> UserDB | None:
    result = await db.execute(select(UserDB).where(UserDB.username == username))
    return result.scalar_one_or_none()


async def get_user_by_email(
    email: str,
    db: AsyncSession,
) -> UserDB | None:
    result = await db.execute(select(UserDB).where(UserDB.email == email))
    return result.scalar_one_or_none()


async def create_user(
    username: str,
    email: str,
    plain_password: str,
    db: AsyncSession,
    role: str = "employee",
) -> UserDB:
    existing_username = await get_user_by_username(username, db)
    if existing_username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Username '{username}' already exists",
        )

    existing_email = await get_user_by_email(email, db)
    if existing_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Email '{email}' already exists",
        )

    user = UserDB(
        username=username,
        email=email,
        hashed_password=hash_password(plain_password),
        role=role,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def username_exists(
    username: str,
    db: AsyncSession,
) -> bool:
    user = await get_user_by_username(username, db)
    return user is not None
