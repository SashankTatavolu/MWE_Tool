from .. import ma


class SentenceSchema(ma.Schema):
    class Meta:
        fields = ('id', 'content', 'is_annotated','is_completed')


sentence_schema = SentenceSchema()
sentences_schema = SentenceSchema(many=True)
