from pydantic import BaseModel, ConfigDict, Field, field_validator


class Input(BaseModel):
    model_config = ConfigDict(extra='forbid', strict=True)


class Login(Input):
    username: str = Field(min_length=3, max_length=24, pattern=r'^[a-zA-Z0-9_]+$')
    password: str = Field(min_length=12, max_length=128)

    @field_validator('username')
    @classmethod
    def normalized(cls, value):
        return value.lower()


class Register(Login):
    display_name: str = Field(min_length=1, max_length=60)


class Profile(Input):
    display_name: str = Field(min_length=1, max_length=60)


class DeleteAccount(Input):
    password: str = Field(min_length=1, max_length=128)


class UserID(Input):
    user_id: str = Field(min_length=1, max_length=64)


class Message(Input):
    text: str = Field(default='', max_length=2000)
    media_id: str | None = Field(default=None, min_length=1, max_length=64)


    @field_validator('text', mode='before')
    @classmethod
    def trim_text(cls, value):
        return value.strip() if isinstance(value, str) else value


class Story(Input):
    media_id: str = Field(min_length=1, max_length=64)
    caption: str = Field(default='', max_length=240)


class Location(Input):
    enabled: bool
    latitude_e6: int | None = Field(default=None, ge=-90000000, le=90000000)
    longitude_e6: int | None = Field(default=None, ge=-180000000, le=180000000)
