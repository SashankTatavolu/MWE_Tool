from .. import ma

class UserSchema(ma.Schema):
    class Meta:
        fields = ('id', 'name', 'email', 'password', 'language', 'registered_on','organisation')

user_schema = UserSchema()
users_schema = UserSchema(many=True)
