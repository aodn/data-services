"""Edit the explicit, closed rows/cells in the local catalogue HTML fixture.

These string edits deliberately avoid using the production parser to build test
inputs, so extraction regressions cannot also change the test setup.
"""
import re


def edit_rows(html, transform, view=None):
    start = html.index('<a id=' + view + '>') if view else 0
    end = html.index('</table>', start) if view else len(html)
    return (html[:start]
            + re.sub(r'<tr>.*?</tr>', lambda match: transform(match[0]), html[start:end], flags=re.S)
            + html[end:])


def has_mission(row, name):
    return '>' + name + '</a>' in row or '>' + name + '</td>' in row


def edit_cells(row, updates):
    cells = iter(enumerate(re.findall(r'<td>.*?</td>', row, flags=re.S)))

    def replace(match):
        index, _ = next(cells)
        return '<td>' + updates[index] + '</td>' if index in updates else match[0]

    return re.sub(r'<td>.*?</td>', replace, row, flags=re.S)
