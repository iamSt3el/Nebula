import QtQuick
import qs.modules.utils
import qs.modules.customComponents

StageRow {
    id: row

    clickable: true

    MaterialIconSymbol {
        content: "chevron_right"
        iconSize: 22
        customColor: row.tonal ? Colors.primaryContainerText : Colors.outline
    }
}
