from .. import ma


class SentenceSchema(ma.Schema):
    class Meta:
        fields = ('id', 'content', 'is_annotated')


sentence_schema = SentenceSchema()
sentences_schema = SentenceSchema(many=True)
