from sqlalchemy.ext.asyncio import AsyncSession

from app_v2.db.user_model import UserDB
from app_v2.db import user_repository


class UserRepository:

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_user_by_username(self, username: str) -> UserDB | None:
        return await user_repository.get_user_by_username(username, self.db)

    async def get_user_by_email(self, email: str) -> UserDB | None:
        return await user_repository.get_user_by_email(email, self.db)

    async def create_user(
        self,
        username: str,
        email: str,
        plain_password: str,
        role: str = "employee",
    ) -> UserDB:
        return await user_repository.create_user(
            username, email, plain_password, self.db, role
        )

    async def username_exists(self, username: str) -> bool:
        return await user_repository.username_exists(username, self.db)
