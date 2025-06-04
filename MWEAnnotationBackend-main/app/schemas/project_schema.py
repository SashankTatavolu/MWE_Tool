from .. import ma


class ProjectSchema(ma.Schema):
    class Meta:
        fields = ('id', 'title', 'description', 'language')


project_schema = ProjectSchema()
projects_schema = ProjectSchema(many=True)
