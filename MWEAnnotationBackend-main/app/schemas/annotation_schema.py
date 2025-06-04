from .. import ma


class AnnotationSchema(ma.Schema):
    class Meta:
        fields = ('word_phrase', 'annotation', 'sentence_id', 'project_id')


annotation_schema = AnnotationSchema()
annotations_schema = AnnotationSchema(many=True)
